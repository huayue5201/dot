-- lua/todo/link/utils.lua
local M = {}

---------------------------------------------------------------------
-- 生成唯一 ID
---------------------------------------------------------------------
function M.generate_id()
	return string.format("%06x", math.random(0, 0xFFFFFF))
end

---------------------------------------------------------------------
-- 在 TODO 文件中查找任务插入位置
---------------------------------------------------------------------
function M.find_task_insert_position(lines)
	for i, line in ipairs(lines) do
		if line:match("^%s*[-*]%s+%[[ xX]%]") then
			return i
		end
	end

	for i, line in ipairs(lines) do
		if line:match("^#+ ") then
			for j = i + 1, #lines do
				if lines[j] == "" then
					return j + 1
				end
			end
			return i + 1
		end
	end

	return 1
end

---------------------------------------------------------------------
-- 获取注释前缀
---------------------------------------------------------------------
function M.get_comment_prefix()
	local cs = vim.bo.commentstring or "%s"
	cs = cs:gsub("^%s+", ""):gsub("%s+$", "")

	local block_prefix = cs:match("^(.*)%%s")
	if block_prefix then
		block_prefix = block_prefix:gsub("%s+$", "")
		return block_prefix
	end

	return "//"
end

---------------------------------------------------------------------
-- 检查是否在 TODO 浮动窗口中
---------------------------------------------------------------------
function M.is_todo_floating_window(win_id)
	win_id = win_id or vim.api.nvim_get_current_win()

	if not vim.api.nvim_win_is_valid(win_id) then
		return false
	end

	local win_config = vim.api.nvim_win_get_config(win_id)
	local is_float = win_config.relative ~= ""

	if not is_float then
		return false
	end

	-- 检查buffer是否是TODO文件
	local bufnr = vim.api.nvim_win_get_buf(win_id)
	local bufname = vim.api.nvim_buf_get_name(bufnr)

	return bufname:match("%.todo%.md$") or bufname:match("todo")
end

return M
