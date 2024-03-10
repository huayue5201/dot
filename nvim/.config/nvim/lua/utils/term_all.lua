-- term_all.lua
local M = {}

-- 初始化或切换 ToggleTerm
M.init_or_toggle = function()
	-- 使用 Vim 命令 ToggleTermToggleAll 切换所有的 ToggleTerm 窗口
	vim.cmd([[ ToggleTermToggleAll ]])

	-- 列出当前缓冲区
	local buffers = vim.api.nvim_list_bufs()

	-- 检查 ToggleTerm 缓冲区是否存在。如果不存在，则通过 vim.cmd [[ exe 1 . "ToggleTerm" ]] 创建一个
	local toggleterm_exists = false
	for _, buf in ipairs(buffers) do
		local buf_name = vim.api.nvim_buf_get_name(buf)
		if buf_name:find("toggleterm#") then
			toggleterm_exists = true
			break
		end
	end

	-- 如果 ToggleTerm 缓冲区不存在，则创建一个
	if not toggleterm_exists then
		vim.cmd([[ exe 1 . "ToggleTerm" ]])
	end
end

return M
