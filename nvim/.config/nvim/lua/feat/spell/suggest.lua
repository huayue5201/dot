-- 建议层：`z=` 的现代替代（picker + 上下文 + 一键全部替换 + 撤回）
--
-- 为什么要换掉原生 `z=`：它是阻塞式的命令行编号菜单，没有上下文、不能预览、
-- 不能一次改全 buffer。而 `spellsuggest()` 实测 ~30ms/次（跟 `best`/`double`/
-- `fast` 无关，瓶颈是查词典），只在用户真的要看建议时调一次，完全无感。
--
-- 替换走 `nvim_buf_set_text`，因此进 undo 树（原生 `z=` 的替换只能靠 `.` 重做、
-- 不进 undo 分支，误替换很难退）—— 另外还留了一条自己的历史栈给 <leader>zu。

local M = {}

local picker = require("ui.picker")
local dict = require("feat.spell.dict")
local diag = require("feat.spell.diag")

local SUGGEST_COUNT = 12
local MAX_UNDO = 50

---@type table<integer, {buf: integer, row: integer, s: integer, e: integer, old: string}[]>
local undo_stack = {}

---@param c string
local function is_kw(c)
	return c ~= "" and c:match("[%w_]") ~= nil
end

--- 光标下的词：优先用 spell.check 找到精确的错词范围，找不到就按关键字字符切
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based
---@return string|nil word
---@return integer s 0-based 起始字节
---@return integer e 0-based 结束字节（不含）
local function span_at(buf, row, col)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	if line == "" then
		return nil
	end
	local ok, hits = pcall(vim.spell.check, line)
	if ok then
		for _, h in ipairs(hits) do
			local s = h[3] - 1
			local e = s + #h[1]
			if col >= s and col <= e then
				return h[1], s, e
			end
		end
	end
	local s = math.min(col, #line)
	while s > 0 and is_kw(line:sub(s, s)) do
		s = s - 1
	end
	local e = math.min(col + 1, #line)
	while e < #line and is_kw(line:sub(e + 1, e + 1)) do
		e = e + 1
	end
	if e <= s then
		return nil
	end
	local word = line:sub(s + 1, e)
	if word == "" then
		return nil
	end
	return word, s, e
end

--- 单词在 buffer 里出现的次数（按关键字边界算，用于「全部替换」的预期）
---@param buf integer
---@param word string
---@return integer
local function count_word(buf, word)
	local n = 0
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local init = 1
		while true do
			local s, e = line:find(word, init, true)
			if not s then
				break
			end
			local before = s > 1 and line:sub(s - 1, s - 1) or ""
			local after = e < #line and line:sub(e + 1, e + 1) or ""
			if not is_kw(before) and not is_kw(after) then
				n = n + 1
			end
			init = e + 1
		end
	end
	return n
end

---@param buf integer
---@param entries table[]
local function push_undo(buf, entries)
	undo_stack[buf] = undo_stack[buf] or {}
	local stack = undo_stack[buf]
	stack[#stack + 1] = entries
	if #stack > MAX_UNDO then
		table.remove(stack, 1)
	end
end

--- 用 set_text 改字（进 undo 树），并记一条撤回记录
---@param buf integer
---@param row integer
---@param s integer
---@param e integer
---@param new string
---@return table entry
local function replace_span(buf, row, s, e, new)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	local old = line:sub(s + 1, e)
	vim.api.nvim_buf_set_text(buf, row, s, row, e, { new })
	return { buf = buf, row = row, s = s, e = s + #new, old = old }
end

--- 全部替换（按关键字边界，单条撤回记录）
---@param buf integer
---@param word string
---@param new string
---@return integer changed
function M.replace_all(buf, word, new)
	buf = buf or vim.api.nvim_get_current_buf()
	local entries = {}
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	-- 从下往上改：行内 col 不受前面的修改影响，行号也不受影响
	for row = #lines, 1, -1 do
		local line = lines[row]
		local spans = {}
		local init = 1
		while true do
			local s, e = line:find(word, init, true)
			if not s then
				break
			end
			local before = s > 1 and line:sub(s - 1, s - 1) or ""
			local after = e < #line and line:sub(e + 1, e + 1) or ""
			if not is_kw(before) and not is_kw(after) then
				spans[#spans + 1] = { s - 1, e }
			end
			init = e + 1
		end
		for i = #spans, 1, -1 do
			entries[#entries + 1] = replace_span(buf, row - 1, spans[i][1], spans[i][2], new)
		end
	end
	if #entries > 0 then
		push_undo(buf, entries)
	end
	diag.update(buf)
	return #entries
end

--- 撤回上一次替换
---@return boolean
function M.undo()
	local buf = vim.api.nvim_get_current_buf()
	local stack = undo_stack[buf]
	local entries = stack and stack[#stack]
	if not entries then
		vim.notify("没有可撤回的拼写替换", vim.log.levels.INFO)
		return false
	end
	for i = #entries, 1, -1 do
		local en = entries[i]
		if vim.api.nvim_buf_is_valid(en.buf) then
			pcall(vim.api.nvim_buf_set_text, en.buf, en.row, en.s, en.row, en.e, { en.old })
		end
	end
	table.remove(stack)
	local first = entries[#entries]
	if vim.api.nvim_buf_is_valid(first.buf) then
		vim.api.nvim_win_set_cursor(0, { first.row + 1, first.s })
	end
	diag.update(buf)
	vim.notify(("已撤回 %d 处替换"):format(#entries), vim.log.levels.INFO)
	return true
end

--- 把词记进词典（并刷新当前 buffer 的诊断）
---@param word string
---@param scope "project"|"global"
---@param buf integer
local function add_word(word, scope, buf)
	local ok, file = dict.add(word, scope, buf)
	if not ok then
		return
	end
	diag.update(buf)
	local where = scope == "project" and "项目词典" or "个人词典"
	vim.notify(("%s → %s"):format(word, where) .. "\n" .. file, vim.log.levels.INFO)
end

--- 建议列表的预览：光标前后几行，目标词替换成候选
---@param buf integer
---@param row integer 0-based
---@param s integer
---@param e integer
---@param old string
---@return fun(new: string): string[]
local function previewer(buf, row, s, e, old)
	return function(new)
		local lines = vim.api.nvim_buf_get_lines(buf, math.max(0, row - 2), row + 3, false)
		local base = math.max(0, row - 2)
		local out = {}
		for i, line in ipairs(lines) do
			if base + i - 1 == row then
				out[#out + 1] = line:sub(1, s) .. new .. line:sub(e + 1)
				out[#out + 1] = ("> "):rep(s) .. ("^"):rep(#new) .. "  ← " .. old
			else
				out[#out + 1] = line
			end
		end
		return out
	end
end

--- 打开建议 picker（默认绑 `z=`）
function M.pick()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= "" then
		vim.notify("这个 buffer 不支持拼写替换", vim.log.levels.INFO)
		return
	end
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local word, s, e = span_at(buf, row, col)
	if not word then
		vim.notify("光标下没有单词", vim.log.levels.INFO)
		return
	end
	if vim.bo[buf].spellfile == "" then
		dict.attach(buf)
	end

	local ok, sugs = pcall(vim.fn.spellsuggest, word, SUGGEST_COUNT)
	if not ok or #sugs == 0 then
		vim.notify(("没有 %s 的建议（可用 zg 收进词典）"):format(word), vim.log.levels.INFO)
		return
	end
	local total = count_word(buf, word)
	local preview = previewer(buf, row, s, e, word)

	picker.pick({
		title = ("拼写建议 %s%s · "):format(word, total > 1 and (" ×" .. total) or ""),
		items = sugs,
		text = function(sug)
			return sug
		end,
		preview = preview,
		filetype = vim.bo[buf].filetype,
		actions = {
			{
				key = "<C-a>",
				desc = "全部替换",
				fn = function(sug, ctx)
					ctx.close()
					local n = M.replace_all(buf, word, sug)
					vim.notify(("替换 %d 处: %s → %s"):format(n, word, sug), vim.log.levels.INFO)
				end,
			},
			{
				key = "a",
				desc = "收进项目词典",
				fn = function(_, ctx)
					ctx.close()
					add_word(word, "project", buf)
				end,
			},
			{
				key = "A",
				desc = "收进个人词典",
				fn = function(_, ctx)
					ctx.close()
					add_word(word, "global", buf)
				end,
			},
			{
				key = "w",
				desc = "标记为错词(zw)",
				fn = function(_, ctx)
					ctx.close()
					pcall(vim.cmd, "silent! spellwrong " .. vim.fn.fnameescape(word))
					diag.update(buf)
				end,
			},
			{
				key = "i",
				desc = "本次忽略",
				fn = function(_, ctx)
					ctx.close()
					pcall(vim.cmd, "silent! spellgood " .. vim.fn.fnameescape(word))
					diag.update(buf)
				end,
			},
		},
		on_choose = function(sug)
			local entries = { replace_span(buf, row, s, e, sug) }
			push_undo(buf, entries)
			diag.update(buf)
		end,
	})
end

--- 光标处浮窗列建议（只看不改，重操作走 z= 的 picker）
function M.hover()
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local word = span_at(buf, row, col)
	if not word then
		return
	end
	local ok, sugs = pcall(vim.fn.spellsuggest, word, 9)
	if not ok or #sugs == 0 then
		vim.notify(("没有 %s 的建议"):format(word), vim.log.levels.INFO)
		return
	end
	local lines = { ("%s → %d 条建议（z= 选择）"):format(word, #sugs) }
	for i, sug in ipairs(sugs) do
		lines[#lines + 1] = ("%d. %s"):format(i, sug)
	end
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	local fbuf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = fbuf })
	local fwin = vim.api.nvim_open_win(fbuf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width + 2,
		height = #lines,
		style = "minimal",
		border = "rounded",
	})
	local group = vim.api.nvim_create_augroup("SpellHover", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
		group = group,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(fwin) then
				pcall(vim.api.nvim_win_close, fwin, true)
			end
		end,
	})
end

M.count_word = count_word
M.span_at = span_at

return M
