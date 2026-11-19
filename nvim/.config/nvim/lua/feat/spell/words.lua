-- 项目技术词候选：从代码里「高频但不认识」的子词里挑词收进词典
--
-- 为什么不是「补全 dirtytalk 词表」：那是一份 2021 年后基本停更的静态词表
-- （tsx/bun/pnpm/biome 这类词都没有），而每个项目自己的技术词是可以从代码里
-- 统计出来的 —— 这正好是 cspell 的 project dictionary 在做的事。
--
-- 关键：收进去的必须是 **camel 拆开后的 lowercase 子词**。因为
-- `spelloptions=camel` 会把 DynamicConfig 拆成 Dynamic + Config 分别查词典，
-- 直接塞 "DynamicConfig" 永远命中不了。（Vim 允许首字母大写的词匹配小写词条，
-- 所以只存小写就够了。）
--
-- `foo_bar_baz` → foo/bar/baz 这种已经在词典里的词会在过滤阶段被扔掉，
-- 真正冒出来的是 dynamodb / rustowl / textobjects 这类项目专有词。

local M = {}

local picker = require("ui.picker")
local dict = require("feat.spell.dict")
local diag = require("feat.spell.diag")

local MIN_LEN = 3
local MIN_COUNT = 2
-- 一次最多扫多少行（跨 buffer 统计，避免在大仓库里按一下等半秒）
local MAX_SCAN_LINES = 120000

--- 把标识符拆成子词（snake / kebab / camel / Pascal 都拆）
---@param ident string
---@return string[]
local function subwords(ident)
	local out = {}
	for part in ident:gmatch("[A-Za-z]+") do
		-- fooBar → foo Bar；URLParser → URL Parser
		part = part:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
		for w in part:gmatch("%a+") do
			if #w >= MIN_LEN then
				out[#out + 1] = w:lower()
			end
		end
	end
	return out
end

--- 扫描一批 buffer，返回「出现次数够多、但词典不认识」的子词
---@param bufs integer[]
---@return { word: string, count: integer }[]
function M.candidates(bufs)
	local freq = {}
	local lines_seen = 0
	for _, buf in ipairs(bufs) do
		for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			lines_seen = lines_seen + 1
			if lines_seen > MAX_SCAN_LINES then
				break
			end
			for ident in line:gmatch("[A-Za-z_][A-Za-z0-9_]*") do
				for _, w in ipairs(subwords(ident)) do
					freq[w] = (freq[w] or 0) + 1
				end
			end
		end
	end

	local known = dict.known()
	local out = {}
	for w, n in pairs(freq) do
		if n >= MIN_COUNT and not known[w] then
			-- spell.check 返回空表 = 这词词典认识，不用收
			local ok, res = pcall(vim.spell.check, w)
			if ok and #res > 0 and res[1][2] == "bad" then
				out[#out + 1] = { word = w, count = n }
			end
		end
	end
	table.sort(out, function(a, b)
		return a.count > b.count or (a.count == b.count and a.word < b.word)
	end)
	return out
end

--- 收集「属于当前项目」的代码 buffer
---@return integer[]
local function project_bufs()
	local root = dict.root(0)
	local bufs = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				local same = root and dict.root(buf) == root
				if root then
					if same then
						bufs[#bufs + 1] = buf
					end
				else
					bufs[#bufs + 1] = buf
				end
			end
		end
	end
	if #bufs == 0 then
		bufs[1] = vim.api.nvim_get_current_buf()
	end
	return bufs
end

---@param word string
---@param scope "project"|"global"
---@param buf integer
local function add(word, scope, buf)
	local ok, file = dict.add(word, scope, buf)
	if ok then
		diag.update(buf)
		vim.notify(("已收录 %s → %s"):format(word, file), vim.log.levels.INFO)
	end
end

--- 打开候选列表；收录/跳过后重开剩下的（picker 的 <CR> 会关窗，不重开就得
--- 为每个词按一次 :SpellPromote）
---@param cands { word: string, count: integer }[]
---@param buf integer
local function open(cands, buf)
	if #cands == 0 then
		vim.notify("候选处理完了", vim.log.levels.INFO)
		return
	end
	local function drop(list, item)
		local rest = {}
		for _, v in ipairs(list) do
			if v ~= item then
				rest[#rest + 1] = v
			end
		end
		open(rest, buf)
	end
	picker.pick({
		title = "技术词候选",
		items = cands,
		text = function(it)
			return ("%5d  %s"):format(it.count, it.word)
		end,
		actions = {
			{
				-- 候选动辄几百条，逐个回车不现实：先用输入框筛（比如敲 "dynam"），
				-- 再把当前可见的全部收进项目词典
				key = "<C-a>",
				desc = "收录所有可见",
				fn = function(_, ctx)
					local visible = ctx.visible()
					local seen = {}
					for _, it in ipairs(visible) do
						seen[it] = true
						add(it.word, "project", buf)
					end
					ctx.close()
					local rest = {}
					for _, it in ipairs(cands) do
						if not seen[it] then
							rest[#rest + 1] = it
						end
					end
					open(rest, buf)
				end,
			},
			{
				key = "A",
				desc = "收进个人词典",
				fn = function(it, ctx)
					ctx.close()
					add(it.word, "global", buf)
					drop(cands, it)
				end,
			},
			{
				key = "<C-d>",
				desc = "跳过",
				fn = function(it, ctx)
					ctx.close()
					drop(cands, it)
				end,
			},
		},
		on_choose = function(it)
			add(it.word, "project", buf)
			drop(cands, it)
		end,
	})
end

--- `:SpellPromote`：列出候选，回车收进项目词表
function M.promote()
	local buf = vim.api.nvim_get_current_buf()
	local cands = M.candidates(project_bufs())
	open(cands, buf)
end

M.subwords = subwords

return M
