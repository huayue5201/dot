-- 拼写检查的「找错」半层：把错词查出来，语料范围由 treesitter 决定
--
-- 为什么不复用原生 `spell` 高亮：原生高亮只能整 buffer 开，代码里会把标识符
-- 全标红；而这里只需要检查「注释/文档字符串」—— 正好是 nvim-treesitter 查询里
-- 标准的 `@spell` / `@nospell` 捕获（258 种语言有 @spell，markdown 还会用
-- @nospell 排除代码块和链接）。于是：
--
--   * 文本 buffer：原生 spell 开着 → 这里只做「找错」给 :SpellAll 用，不重复画线
--   * 代码 buffer：原生 spell 关着 → 这里把注释里的错词变成 diagnostics
--   * 超大文本 buffer（原生 spell 被主动关了）→ 这里退化成整行检查，仍然能用
--
-- 性能（实测 6 万词 / 4000 行）：`vim.spell.check()` 全量 18.5ms，即 0.3ms/行；
-- 而 `spellsuggest()` 单次就要 30ms —— 所以「找错」可以随便跑，「给建议」必须
-- 懒加载（见 suggest.lua）。这也正是当年 spellwand 卡 2s 的原因：它给每个错词
-- 都算了 suggestions。
--
-- 增量更新：整份扫一遍的耗时跟「这个文件有多少注释」成正比（注释密集的
-- pack.lua 1468 行要 ~50ms：iter_captures 23ms + spell.check 84ms 全行）。
-- 一次卡 50ms 在打字时能感觉到，所以按行分批（CHUNK_ROWS）切片跑，每片之间
-- 让出主线程；buffer 一改（changedtick 变了）就放弃剩下的切片。

local M = {}

local ns = vim.api.nvim_create_namespace("feat.spell")
local DEBOUNCE_MS = 400
-- 每片处理多少行：注释密集时一片约 10~20ms
local CHUNK_ROWS = 300
-- 超过这个行数不做自动检查（一次性扫完要几百毫秒，收益不值）
local MAX_LINES = 20000

---@type table<integer, uv.uv_timer_t>
local timers = {}
---@type table<integer, table> 正在分片跑的更新任务
local jobs = {}

--- 这个 buffer 的窗口上 'spell' 是否开着
--- （注意：vim.wo[num] 的 key 是**窗口 id**，不是 buffer，传 buf 会报 Invalid window id）
---@param buf integer
---@return boolean
local function spell_on(buf)
	local win = vim.fn.bufwinid(buf)
	if win == -1 then
		win = 0
	end
	return vim.wo[win].spell == true
end

---@param buf integer
---@return string|nil
local function lang_of(buf)
	local ft = vim.bo[buf].filetype
	if ft == "" then
		return nil
	end
	local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
	if ok and lang then
		return lang
	end
	return ft
end

--- 把 holes 从 ranges 里挖掉（都是 0-based 字节区间，ecol 不含）
--- @param ranges integer[][]
--- @param holes integer[][]
--- @return integer[][]
local function subtract(ranges, holes)
	if #holes == 0 then
		return ranges
	end
	local out = {}
	for _, r in ipairs(ranges) do
		local cur = { r[1], r[2], r[3], r[4] }
		for _, h in ipairs(holes) do
			if cur and h[1] <= cur[3] and h[3] >= cur[1] then
				if h[1] <= cur[1] and h[3] >= cur[3] then
					cur = nil
					break
				end
				-- 简化处理：@nospell 区间通常很小（单个链接/代码块），
				-- 只处理「同一行内挖中间」这一种，跨行时宁可多查几个词
				if cur[1] == cur[3] and h[1] == h[3] and h[2] > cur[2] and h[4] < cur[4] then
					out[#out + 1] = { cur[1], cur[2], cur[1], h[2] }
					cur = { cur[1], h[4], cur[1], cur[4] }
				end
			end
		end
		if cur then
			out[#out + 1] = cur
		end
	end
	return out
end

---@class feat.spell.hit
---@field lnum integer 1-based 行号
---@field col integer 0-based 起始字节列
---@field end_col integer 0-based 结束字节列（不含）
---@field word string 错词

--- 取 [row_start, row_end) 行内「该查拼写」的片段
---@param buf integer
---@param query vim.treesitter.Query
---@param root vim.treesitter.Node
---@param row_start integer 0-based
---@param row_end integer 0-based（不含）
---@param lines string[]
---@return integer[][] {{row0, col_start0, col_end0}}
local function ts_pieces(buf, query, root, row_start, row_end, lines)
	local spell, nospell = {}, {}
	for id, node in query:iter_captures(root, buf, row_start, row_end) do
		local name = query.captures[id]
		if name == "spell" then
			spell[#spell + 1] = { node:range() }
		elseif name == "nospell" then
			nospell[#nospell + 1] = { node:range() }
		end
	end
	local ranges = subtract(spell, nospell)

	local per_row = {}
	for _, r in ipairs(ranges) do
		for row = r[1], r[3] do
			if row >= row_start and row < row_end then
				local line = lines[row + 1] or ""
				local s = row == r[1] and r[2] or 0
				local e = row == r[3] and math.min(r[4], #line) or #line
				if e > s then
					per_row[row] = per_row[row] or {}
					per_row[row][#per_row[row] + 1] = { s, e }
				end
			end
		end
	end

	local pieces = {}
	for row, list in pairs(per_row) do
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		for _, seg in ipairs(list) do
			local last = pieces[#pieces]
			if last and last[1] == row and seg[1] <= last[3] then
				last[3] = math.max(last[3], seg[2])
			else
				pieces[#pieces + 1] = { row, seg[1], seg[2] }
			end
		end
	end
	table.sort(pieces, function(a, b)
		return a[1] == b[1] and a[2] < b[2] or a[1] < b[1]
	end)
	return pieces
end

--- 检查一批片段，转成 hit
---@param lines string[]
---@param pieces integer[][]
---@param out feat.spell.hit[]
local function check_pieces(lines, pieces, out)
	for _, p in ipairs(pieces) do
		local text = (lines[p[1] + 1] or ""):sub(p[2] + 1, p[3])
		if text ~= "" then
			local ok, res = pcall(vim.spell.check, text)
			if ok then
				for _, item in ipairs(res) do
					local word, kind, start = item[1], item[2], item[3]
					if kind == "bad" or kind == "rare" then
						local s = p[2] + start - 1
						out[#out + 1] = { lnum = p[1] + 1, col = s, end_col = s + #word, word = word }
					end
				end
			end
		end
	end
end

--- 整 buffer 同步扫（:SpellAll 用；显式命令，一次 50ms 可以接受）
--- 原生 spell 开着时按整行查，否则走 treesitter 的 @spell 区间。
---@param buf? integer
---@return feat.spell.hit[]
function M.scan(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return {}
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 or #lines > MAX_LINES then
		return {}
	end

	local pieces
	local whole = spell_on(buf) or (lang_of(buf) == nil)
	if not whole then
		local lang = lang_of(buf)
		local okq, query = pcall(vim.treesitter.query.get, lang, "highlights")
		local okp, parser = pcall(vim.treesitter.get_parser, buf, lang)
		if okq and query and okp and parser then
			local okr, trees = pcall(parser.parse, parser)
			if okr and trees and #trees > 0 then
				pieces = ts_pieces(buf, query, trees[1]:root(), 0, #lines, lines)
			end
		end
	else
		pieces = {}
		for i = 1, #lines do
			pieces[i] = { i - 1, 0, #lines[i] }
		end
	end
	-- 没有 @spell 查询：文本类 filetype 退回整行，代码类什么都不查（不误报标识符）
	if not pieces then
		if not require("feat.spell").is_text(vim.bo[buf].filetype) then
			return {}
		end
		pieces = {}
		for i = 1, #lines do
			pieces[i] = { i - 1, 0, #lines[i] }
		end
	end

	local hits = {}
	check_pieces(lines, pieces, hits)
	return hits
end

---@param buf integer
---@param items vim.Diagnostic[]
local function apply(buf, items)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.diagnostic.set(ns, buf, items)
end

---@param h feat.spell.hit
---@return vim.Diagnostic
local function to_diag(h)
	return {
		lnum = h.lnum - 1,
		col = h.col,
		end_lnum = h.lnum - 1,
		end_col = h.end_col,
		message = h.word,
		severity = vim.diagnostic.severity.WARN,
		source = "spell",
	}
end

--- 增量更新诊断（分片跑，每片之间让出主线程）
---@param buf integer
function M.update(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	-- 原生高亮开着就别画两份
	if spell_on(buf) then
		jobs[buf] = nil
		vim.diagnostic.reset(ns, buf)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 or #lines > MAX_LINES then
		jobs[buf] = nil
		vim.diagnostic.reset(ns, buf)
		return
	end

	local lang = lang_of(buf)
	local query, root
	local is_text = lang == nil or require("feat.spell").is_text(vim.bo[buf].filetype)
	if lang then
		local okq, q = pcall(vim.treesitter.query.get, lang, "highlights")
		local okp, parser = pcall(vim.treesitter.get_parser, buf, lang)
		if okq and q and okp and parser then
			local okr, trees = pcall(parser.parse, parser)
			if okr and trees and #trees > 0 then
				query, root = q, trees[1]:root()
			end
		end
	end
	if not query and not is_text then
		jobs[buf] = nil
		vim.diagnostic.reset(ns, buf)
		return
	end

	local tick = vim.api.nvim_buf_get_changedtick(buf)
	local job = { row = 0, items = {}, tick = tick }
	jobs[buf] = job

	local function step()
		-- 被新的更新顶掉 / buffer 变了 / buffer 没了 → 放弃剩余分片
		if jobs[buf] ~= job or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
			return
		end
		local stop = math.min(job.row + CHUNK_ROWS, #lines)
		local pieces = {}
		if query then
			pieces = ts_pieces(buf, query, root, job.row, stop, lines)
		else
			for row = job.row, stop - 1 do
				pieces[#pieces + 1] = { row, 0, #(lines[row + 1] or "") }
			end
		end
		local hits = {}
		check_pieces(lines, pieces, hits)
		for _, h in ipairs(hits) do
			job.items[#job.items + 1] = to_diag(h)
		end
		job.row = stop
		if job.row >= #lines then
			jobs[buf] = nil
			apply(buf, job.items)
		else
			vim.schedule(step)
		end
	end
	vim.schedule(step)
end

--- 防抖：连续输入只在停手 400ms 后跑一次
---@param buf integer
---@param delay? integer
function M.schedule(buf, delay)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local timer = timers[buf]
	if not timer then
		timer = vim.uv.new_timer()
		timers[buf] = timer
	end
	timer:stop()
	timer:start(
		delay or DEBOUNCE_MS,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(buf) then
				M.update(buf)
			end
		end)
	)
end

---@param buf integer
function M.detach(buf)
	local timer = timers[buf]
	if timer then
		timer:stop()
		timer:close()
		timers[buf] = nil
	end
	jobs[buf] = nil
	vim.diagnostic.reset(ns, buf)
end

--- 当前 buffer 的拼写诊断
---@param buf? integer
---@return vim.Diagnostic[]
function M.get(buf)
	return vim.diagnostic.get(buf or 0, { namespace = ns })
end

M.namespace = ns

vim.diagnostic.config({
	virtual_text = false,
	signs = false,
	underline = true,
	severity_sort = true,
}, ns)

return M
