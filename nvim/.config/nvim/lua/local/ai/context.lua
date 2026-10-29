-- lua/local/ai/context.lua
---@brief 采集「提问锚点」：告诉接收方问题是在哪个项目 / tab / 文件 / 行 / 选区上问的。
--
-- 存在的理由：多 tab 多项目时（tab_workspace 用 :tcd 给每个 tab 独立 cwd），
-- 只有 nvim 自己知道「你现在看的是哪个项目」。与其让外部 agent 去猜，
-- 不如在提问的瞬间把锚点钉死，随问题一起发出去。
--
-- 纯采集，不认识任何 agent —— 谁收都一样。

local M = {}

--- 抓锚点。visual=true 时用当前 visual 选区（当场读 getpos("v")/(.)，不依赖 '< '>）
---@param visual boolean|nil
---@return table anchor
function M.capture(visual)
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local name = vim.api.nvim_buf_get_name(buf)
	local path = name ~= "" and vim.fn.fnamemodify(name, ":p") or nil
	local a = {
		cwd = vim.fn.getcwd(),
		tab = vim.fn.tabpagenr(),
		path = path and vim.fn.fnamemodify(path, ":~:.") or nil,
		line = cursor[1],
		col = cursor[2] + 1,
		filetype = vim.bo[buf].filetype,
		modified = vim.bo[buf].modified,
	}
	if visual then
		local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
		local sl, el = math.min(s[2], e[2]), math.max(s[2], e[2])
		if sl > 0 and el > 0 then
			a.visual = {
				start_line = sl,
				end_line = el,
				lines = vim.api.nvim_buf_get_lines(buf, sl - 1, el, false),
			}
			a.line = sl
		end
	end
	return a
end

--- 一句话描述锚点，给浮窗标题用
---@param a table
---@return string
function M.describe(a)
	local bits = { a.path and ("%s:%d"):format(a.path, a.line) or "<无文件名>" }
	if a.visual then
		table.insert(bits, ("选区 %d-%d"):format(a.visual.start_line, a.visual.end_line))
	end
	if a.modified then
		table.insert(bits, "未保存")
	end
	return table.concat(bits, " · ")
end

return M
