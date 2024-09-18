-- utils/largerfile.lua

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

	if line_count > 20000 or (stat and stat.size or 0) > 1 * 1024 * 1024 then
		local options = {
			foldmethod = "manual",
			syntax = "off",
			filetype = "off",
			undofile = false,
			swapfile = false,
			loadplugins = false,
		}

		for key, value in pairs(options) do
			vim.api.nvim_buf_set_option(bufnr, key, value)
		end
	end
end

-- 需要插件自身的启动/关闭命令
local function close_plugin()
	local _, _, _, line_count, file_type = get_buffer_info()
	if file_type == "log" or line_count > 5000 then
		vim.cmd("DisableHL")
	else
		vim.cmd("EnableHL")
	end
end

local M = {}

function M.setup()
	vim.api.nvim_create_autocmd("BufEnter", {
		group = vim.api.nvim_create_augroup("IndentBlanklineBigFile", { clear = true }),
		pattern = "*",
		callback = function()
			big_file_settings()
			-- close_plugin()
		end,
	})
end

return M
