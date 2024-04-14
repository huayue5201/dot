local M = {}

--- 获取缓冲区信息
---@return number, string, table, number, string
local function get_buffer_info()
	local bufnr = vim.api.nvim_get_current_buf() -- 当前缓冲区编号
	local bufname = vim.api.nvim_buf_get_name(bufnr) -- 当前缓冲区名称或路径
	local stat = vim.loop.fs_stat(bufname) -- 文件状态信息
	local line_count = vim.api.nvim_buf_line_count(bufnr) -- 缓冲区行数
	local file_type = vim.api.nvim_buf_get_option(bufnr, "filetype") -- 文件类型
	return bufnr, bufname, stat, line_count, file_type
end

--- 处理大文件时自动调整设置
local function big_file_settings()
	local bufnr, _, stat, line_count, _ = get_buffer_info()
	if line_count > 10000 or (stat and stat.size or 0) > 100 * 1024 then
		vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
		vim.api.nvim_buf_set_option(bufnr, "syntax", "false")
		vim.api.nvim_buf_set_option(bufnr, "filetype", "false")
		vim.api.nvim_buf_set_option(bufnr, "undofile", false)
		vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
		vim.api.nvim_buf_set_option(bufnr, "loadplugins", false)
	end
end

-- 处理大文件时自动关闭/打开插件
-- 需要插件自身的启动/关闭命令
local function close_large_plugin()
	local _, _, _, line_count, file_type = get_buffer_info()
	if file_type == "log" or line_count > 5000 then
		vim.cmd("DisableHL")
	else
		vim.cmd("EnableHL")
	end
end

function M.setup()
	local autocmd = vim.api.nvim_create_autocmd
	local augroup = vim.api.nvim_create_augroup
	autocmd("BufEnter", {
		group = augroup("IndentBlanklineBigFile", { clear = true }),
		pattern = "*",
		callback = function()
			big_file_settings()
			close_large_plugin()
		end,
	})
end

return M
