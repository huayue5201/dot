-- 错误跳转：正则匹配错误行并跳转，支持 . 重复
local M = {}

-- 匹配错误位置的正则表达式
M.error_patterns = {
	-- 匹配 Rust 错误：error[E0425]:
	"^%s*error%[[^%]]+%]:",
	-- TypeScript/JavaScript
	"^%s*error  TS%d+:",
	-- Go
	"^%s*# ",
	"^%s*.*: error:",
	-- 匹配以 warning: 开头的行
	"^%s*warning:",
	-- 匹配以 error: 开头的行
	"^%s*error:",
	"^%s*ERROR:",
	-- 匹配以 panic 相关的行
	"^%s*panic",
	-- 匹配测试失败标记
	"FAILED",
	"failures:",
}

-- 获取当前缓冲区中所有包含错误位置的行号
---@param bufnr? integer
---@return integer[] 行号列表（按顺序排列）
function M.get_error_lines(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local error_lines = {}

	for line_num, line in ipairs(lines) do
		for _, pattern in ipairs(M.error_patterns) do
			if line:find(pattern) then
				table.insert(error_lines, line_num)
				break
			end
		end
	end

	return error_lines
end

-- 跳转到下一个错误位置
function M.next_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	local target = nil
	for _, line_num in ipairs(error_lines) do
		if line_num > current_line then
			target = line_num
			break
		end
	end
	if not target then
		target = error_lines[1]
	end

	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd([[normal! zv]]) -- 展开折叠行
end

-- 跳转到上一个错误位置
function M.prev_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	local target = nil
	for i = #error_lines, 1, -1 do
		if error_lines[i] < current_line then
			target = error_lines[i]
			break
		end
	end
	if not target then
		target = error_lines[#error_lines]
	end

	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd([[normal! zv]]) -- 展开折叠行
end

-- ============================
-- 支持 . 重复的错误跳转
-- 原理：通过 g@ 操作符让 Neovim 记住操作，按 . 时重复执行
-- ============================

local last_jump_direction = nil -- "next" | "prev"

-- 回调函数（供 operatorfunc 使用）
function M._repeat_jump_callback()
	if last_jump_direction == "next" then
		M.next_error()
	elseif last_jump_direction == "prev" then
		M.prev_error()
	end
end

-- 下一个错误（支持 . 重复）
function M.next_error_repeatable()
	last_jump_direction = "next"
	vim.o.operatorfunc = "v:lua.require'user.navigation'._repeat_jump_callback"
	vim.api.nvim_feedkeys("g@l", "i", false)
end

-- 上一个错误（支持 . 重复）
function M.prev_error_repeatable()
	last_jump_direction = "prev"
	vim.o.operatorfunc = "v:lua.require'user.navigation'._repeat_jump_callback"
	vim.api.nvim_feedkeys("g@l", "i", false)
end

return M
