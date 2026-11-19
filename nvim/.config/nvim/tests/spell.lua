-- 拼写检查的行为测试（lua/feat/spell/*）
--
--   nvim --headless -u NONE -l tests/spell.lua
--
-- 覆盖：
--   * 项目根发现 + 词典分层（项目 .nvim-spell 在前，个人词表在后）
--   * 代码 buffer 只查 treesitter 的 @spell 区间（注释），字符串里的错词不报
--   * 文本 buffer 走原生 spell，diag 不再重复画线
--   * 中文（cjk）不误报
--   * 收录进项目词典后错词立刻消失
--   * suggest 的就地替换 / 计数 / 撤回
--   * 技术词候选（camel/snake 子词）能找到代码里的词
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd("filetype on")

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local sp = require("feat.spell")
sp.setup()

-- macOS 的 tempname 走 /var → /private/var 软链，比较路径前先 realpath
local function real(path)
	return vim.uv.fs_realpath(path) or path
end

-- 造一个「项目」：.git 当根标记
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/.git", "p")
vim.fn.mkdir(root .. "/sub", "p")
local lua_file = root .. "/sub/a.lua"
vim.fn.writefile({
	"-- this is teh coment with a typo recieve",
	'local s = "ignore badword string"',
	"local ident_dynamodbclient = 1",
	"local other_dynamodbclient = 2",
}, lua_file)
local md_file = root .. "/note.md"
vim.fn.writefile({
	"# title teh",
	"这是 neovim 配置 recieve 的说明",
}, md_file)

local function edit(path)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	return vim.api.nvim_get_current_buf()
end

local function words_of(hits)
	local seen, out = {}, {}
	for _, h in ipairs(hits) do
		if not seen[h.word] then
			seen[h.word] = true
			out[#out + 1] = h.word
		end
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function wait_for(buf, want)
	return vim.wait(5000, function()
		return #sp.diag.get(buf) == want
	end, 20)
end

----------------------------------------------------------------------
-- 词典分层
----------------------------------------------------------------------
local buf = edit(lua_file)
check(real(sp.dict.root(buf)) == real(root), "项目根应为 " .. root .. "，实际 " .. tostring(sp.dict.root(buf)))
local files = vim.split(vim.bo[buf].spellfile, ",", { plain = true })
check(
	files[1] == real(root) .. "/.nvim-spell/en.utf-8.add",
	"项目词表应排第一（zg 写入它），实际 " .. tostring(files[1])
)
check(files[2] == sp.dict.GLOBAL, "个人词表应排第二，实际 " .. tostring(files[2]))

----------------------------------------------------------------------
-- 代码 buffer：只查注释
----------------------------------------------------------------------
local hits = sp.diag.scan(buf)
local got = words_of(hits)
check(got == "coment,recieve,teh", "代码 buffer 应只报注释里的词，实际: " .. got)

----------------------------------------------------------------------
-- 中文不误报（spelllang 里的 cjk）
----------------------------------------------------------------------
for _, h in ipairs(hits) do
	if h.word:find("[\128-\255]") then
		check(false, "中文不该被当成错词: " .. h.word)
	end
end

----------------------------------------------------------------------
-- 异步分片结果与同步扫描一致
----------------------------------------------------------------------
sp.diag.update(buf)
check(wait_for(buf, #hits), ("异步诊断条数应为 %d，实际 %d"):format(#hits, #sp.diag.get(buf)))

----------------------------------------------------------------------
-- 收录进项目词典 → 立刻消失（不需要重启）
----------------------------------------------------------------------
local ok, addfile = sp.dict.add("coment", "project", buf)
check(ok, "收录应成功: " .. tostring(addfile))
check(
	real(addfile) == real(root) .. "/.nvim-spell/en.utf-8.add",
	"应写进项目词表，实际 " .. tostring(addfile)
)
sp.diag.update(buf)
check(wait_for(buf, #hits - 1), "收录后应少一条诊断，实际 " .. #sp.diag.get(buf))
check(not words_of(sp.diag.scan(buf)):find("coment"), "收录后 coment 不应再被报错")

----------------------------------------------------------------------
-- 文本 buffer：原生 spell 开着，diag 不重复画线
----------------------------------------------------------------------
buf = edit(md_file)
check(sp.is_text(vim.bo[buf].filetype), "markdown 应算文本 buffer")
check(vim.wo.spell == true, "markdown 应自动开原生 spell")
check(vim.bo[buf].spelloptions:find("camel") ~= nil, "文本 buffer 应开 camel")
local mdhits = sp.diag.scan(buf)
check(words_of(mdhits) == "recieve,teh", "markdown 应整行查，实际: " .. words_of(mdhits))
sp.diag.update(buf)
vim.wait(300)
check(#sp.diag.get(buf) == 0, "原生高亮开着时不该有重复诊断，实际 " .. #sp.diag.get(buf))

----------------------------------------------------------------------
-- suggest：就地替换 / 计数 / 撤回
----------------------------------------------------------------------
buf = edit(lua_file)
local w, s, e = sp.suggest.span_at(buf, 0, 12) -- 0-based 行/列，指向 "-- this is teh" 的 teh
check(w == "teh", "span_at 应取到 teh，实际 " .. tostring(w))
check(("-- this is teh"):sub(s + 1, e) == "teh", ("span_at 的范围不对: %d..%d"):format(s, e))
check(sp.suggest.count_word(buf, "teh") == 1, "count_word 应为 1")
local notify = vim.notify
vim.notify = function() end -- replace_all/undo 会 notify，测试里不需要看
local line_before = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
check(sp.suggest.replace_all(buf, "teh", "the") == 1, "replace_all 应替换 1 处")
check(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == line_before:gsub("teh", "the"), "replace_all 文本不对")
sp.suggest.undo()
check(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == line_before, "undo 应还原")
check(sp.suggest.count_word(buf, "teh") == 1, "undo 后 teh 应回来")
vim.notify = notify

----------------------------------------------------------------------
-- 技术词候选：从 identifier 里拆出子词
----------------------------------------------------------------------
local sub = sp.words.subwords("ident_dynamodbclient")
check(vim.tbl_contains(sub, "dynamodbclient"), "应含整词（大小写变体也会试）")
local cands = sp.words.candidates({ buf })
local found = nil
for _, c in ipairs(cands) do
	if c.word == "dynamodbclient" then
		found = c
	end
end
check(found ~= nil, "候选里应出现 dynamodbclient")

vim.cmd("silent! %bwipeout!")

if #fails > 0 then
	for _, msg in ipairs(fails) do
		io.stderr:write("FAIL: " .. msg .. "\n")
	end
	os.exit(1)
end
print("ok: 拼写分层词典/注释诊断/中文不误报/收录生效/替换撤回/技术词候选")
