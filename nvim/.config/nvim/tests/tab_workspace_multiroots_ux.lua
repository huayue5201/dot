-- 用户视角：多根工作区（主根 + 辅助根）从「用」的角度跑一遍。
--
--   nvim --headless -u NONE -l tests/tab_workspace_multiroots_ux.lua
--
-- 覆盖：
--   1. 附加辅助根 → 多根树里并列出现「主 / 辅」，展开能拿到真实文件
--   2. 从辅助根打开文件 → 归属当前 tab（切到别的 tab 看不见）
--   3. 存会话 → 辅助根写进会话文件 → 重新载入后根和 buffer 都回来
--   4. 切 tab：各 tab 的辅助根互不影响；关 tab 后辅助根随之清理
--   5. 辅助根里的 .nvim.lua 不生效（配置只跟主根走，属于设计边界）
--   6. 卸载辅助根 → 树和会话都不再带上它
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

-- 测试环境是 -u NONE：把已装插件目录挂进 runtimepath（neo-tree 依赖 nui/plenary）
local opt = vim.fn.stdpath("data") .. "/site/pack/core/opt"
for _, path in ipairs(vim.fn.glob(opt .. "/*", false, true)) do
	if vim.fn.isdirectory(path) == 1 then
		vim.opt.rtp:prepend(path)
	end
end

local uv = vim.uv or vim.loop
local fails = {}
local orig_notify = vim.notify

local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local function real(path)
	local ok, res = pcall(uv.fs_realpath, path)
	return (ok and res) or path
end

local function mkdirp(path)
	vim.fn.mkdir(path, "p")
end

local function write_file(path, lines)
	vim.fn.writefile(lines, path)
end

local function cwd()
	return real(vim.fn.getcwd())
end

local ok_resession, resession = pcall(require, "resession")
local ok_neotree, neotree = pcall(require, "neo-tree")
if not (ok_resession and ok_neotree) then
	print("skip: 需要 resession 与 neo-tree")
	vim.cmd("qall!")
	os.exit(0)
end

local base = vim.fn.tempname()
local A, B, C = base .. "/projA", base .. "/projB", base .. "/projC"
local sessions = base .. "/sessions"
for _, dir in ipairs({ A, B, C, sessions }) do
	mkdirp(dir)
end
write_file(A .. "/a.txt", { "a" })
write_file(B .. "/b.txt", { "b" })
write_file(C .. "/c.txt", { "c" })

-- 会话落到临时目录，绝不碰真实 ~/.local/share/nvim/session
local files = require("resession.files")
files.get_stdpath_filename = function(_, _)
	return sessions
end

local function session_path(name)
	return sessions .. "/" .. name .. ".json"
end

local function read_raw(name)
	local ok, data = pcall(function()
		local f = assert(io.open(session_path(name)))
		local s = f:read("*a")
		f:close()
		return vim.json.decode(s)
	end)
	return ok and data or nil
end

-- 与 lua/plugins/resession.lua 同款载入清洗
local load_json_file = files.load_json_file
files.load_json_file = function(path)
	local data = load_json_file(path)
	if type(data) == "table" then
		pcall(require("feat.tab_workspace.session").strip_terminal_bufs, data)
		pcall(require("feat.tab_workspace.session_guard").sanitize_cwd, data)
	end
	return data
end

resession.setup({
	dir = "session",
	autosave = { enabled = false },
	load_detail = false,
	buf_filter = function(bufnr)
		return require("feat.tab_workspace.util").is_saved_buf(bufnr)
	end,
	extensions = { tab_workspace = { enable_in_tab = true } },
})

neotree.setup({ sources = { "filesystem", "feat.tab_workspace.neo_tree" } })

local tw = require("feat.tab_workspace")
tw.setup({ auto_root = false })
tw.attach_resession()

local roots = require("feat.tab_workspace.roots")
local state = require("feat.tab_workspace.state")
local workspace = require("feat.tab_workspace.workspace")
local manager = require("neo-tree.sources.manager")

vim.notify = function() end

local function reset()
	pcall(vim.cmd, "silent! tabonly")
	pcall(vim.cmd, "enew!")
	local cur = vim.api.nvim_get_current_buf()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if b ~= cur and vim.api.nvim_buf_is_valid(b) then
			pcall(vim.api.nvim_buf_delete, b, { force = true })
		end
	end
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		roots.clear(tab)
	end
	state.reset()
end

local function edit(path)
	vim.cmd.edit({ args = { path } })
end

local function tcd(dir)
	vim.cmd.tcd({ args = { dir } })
end

local function tab()
	return vim.api.nvim_get_current_tabpage()
end

local function aux_names(t)
	local out = {}
	for _, dir in ipairs(roots.aux(t)) do
		out[#out + 1] = real(dir)
	end
	return out
end

local function tree_root()
	local st = manager.get_state("workspace")
	return st and st.tree:get_nodes("workspace://roots") or {}
end

local function tree_state()
	return manager.get_state("workspace")
end

local function wait_tree()
	vim.wait(3000, function()
		local st = tree_state()
		return st and st.tree ~= nil
	end, 20)
end

----------------------------------------------------------------------
-- 1. 附加辅助根：状态栏数据 + 多根树并列展示
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a.txt")

local ok_attach, err = workspace.attach_root(B)
check(ok_attach, "附加 projB 应成功: " .. tostring(err))
check(#roots.aux(tab()) == 1 and real(roots.aux(tab())[1]) == real(B), "辅助根应是 projB")

require("neo-tree.command").execute({ source = "workspace", action = "show" })
wait_tree()
local top = tree_root()
local kinds = {}
for _, node in ipairs(top) do
	kinds[#kinds + 1] = tostring(node.extra and node.extra.workspace_root) .. ":" .. real(node.id)
end
check(#top == 2, ("多根树顶层应有 2 个根，实际 %d（%s）"):format(#top, table.concat(kinds, ",")))
check(kinds[1] == "primary:" .. real(A), "第一个根应是主根 projA，实际 " .. tostring(kinds[1]))
check(kinds[2] == "aux:" .. real(B), "第二个根应是辅助根 projB，实际 " .. tostring(kinds[2]))

-- 展开辅助根：拿到真实文件
local st = tree_state()
require("neo-tree.sources.filesystem.lib.fs_scan").get_items(st, real(B), nil, function() end, false)
vim.wait(3000, function()
	local kids = st.tree:get_nodes(real(B)) or {}
	return #kids > 0
end, 20)
local aux_kids = st.tree:get_nodes(real(B)) or {}
local found_b = false
for _, kid in ipairs(aux_kids) do
	if kid.name == "b.txt" then
		found_b = true
	end
end
check(found_b, "展开辅助根应看到 projB/b.txt")

----------------------------------------------------------------------
-- 2. 从辅助根打开文件：归属当前 tab
----------------------------------------------------------------------

edit(B .. "/b.txt")
local tab1 = tab()
local buf_b = vim.api.nvim_get_current_buf()
check(state.is_owned(tab1, buf_b), "projB/b.txt 应归属当前 tab")
check(vim.bo[buf_b].buflisted, "当前 tab 里 b.txt 应 listed")

----------------------------------------------------------------------
-- 3. 会话往返：辅助根跟着会话走
----------------------------------------------------------------------

resession.save("S_MR", { notify = false })
local saved = read_raw("S_MR")
check(saved ~= nil, "会话文件应写入")
local entry = saved and saved.tab_workspace and saved.tab_workspace.list and saved.tab_workspace.list[1]
check(entry ~= nil, "会话应有 tab 段落")
check(
	type(entry.aux) == "table" and #entry.aux == 1 and real(entry.aux[1]) == real(B),
	"会话应记录辅助根 projB，实际 " .. vim.inspect(entry and entry.aux)
)

reset()
tcd(C)
edit(C .. "/c.txt")
workspace.load_session("S_MR", { attach = true })
check(cwd() == real(A), "载入后主根应是 projA，实际 " .. cwd())
check(#roots.aux(tab()) == 1 and real(roots.aux(tab())[1]) == real(B), "载入后辅助根应恢复为 projB")
local names = {}
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.bo[b].buflisted and vim.bo[b].buftype == "" then
		names[#names + 1] = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t")
	end
end
table.sort(names)
check(
	vim.tbl_contains(names, "a.txt") and vim.tbl_contains(names, "b.txt"),
	"载入后应恢复两个文件: " .. table.concat(names, ",")
)

----------------------------------------------------------------------
-- 4. 切 tab / 关 tab：辅助根按 tab 隔离并被清理
----------------------------------------------------------------------

vim.cmd.tabnew()
tcd(C)
edit(C .. "/c.txt")
local tab2 = tab()
check(#roots.aux(tab2) == 0, "新 tab 不应继承辅助根")
roots.attach(tab2, A)
check(#roots.aux(tab2) == 1, "新 tab 可独立附加辅助根")

vim.cmd("tabprevious")
check(#roots.aux(tab()) == 1, "切回 tab1 后辅助根应还在")

vim.cmd("tabnext")
vim.cmd("tabclose")
vim.wait(200, function()
	return true
end)
check(#roots.aux(tab()) == 1, "关掉 tab2 不应影响 tab1 的辅助根")

----------------------------------------------------------------------
-- 5. 辅助根里的 .nvim.lua 不生效（配置只跟主根）
----------------------------------------------------------------------

local orig_tabstop = vim.bo.tabstop
write_file(B .. "/.nvim.lua", { "w.opt({ tabstop = 9 })" })
require("feat.tab_workspace.local_settings").reload()
check(vim.bo.tabstop == orig_tabstop, "辅助根的 .nvim.lua 不应被加载（当前设计边界）")

----------------------------------------------------------------------
-- 6. 卸载辅助根：树与会话都不再带上它
----------------------------------------------------------------------

require("neo-tree.command").execute({ source = "workspace", action = "show" })
wait_tree()
workspace.detach_root(B)
vim.wait(1000, function()
	return #tree_root() == 1
end, 20)
check(#roots.aux(tab()) == 0, "卸载后辅助根应为空")
check(#tree_root() == 1, ("卸载后多根树应只剩主根，实际 %d"):format(#tree_root()))

workspace.save_session()
local after = read_raw("S_MR")
check(
	after
		and after.tab_workspace
		and after.tab_workspace.list
		and after.tab_workspace.list[1]
		and after.tab_workspace.list[1].aux == nil,
	"辅助根全部卸载后会话不应再写 aux"
)

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

vim.notify = orig_notify
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: 多根工作区的用户流程（树/归属/会话/切 tab/卸载）符合预期")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
