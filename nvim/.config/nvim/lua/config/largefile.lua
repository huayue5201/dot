local M = {}

--- 获取缓冲区信息
---@return number, string, table, number, string
local function get_buffer_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local stat = vim.fn.stat(bufname) -- 使用 vim.fn.stat 来代替 vim.loop.fs_stat
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local file_type = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	return bufnr, bufname, stat, line_count, file_type
end

--- 判断是否为大文件
---@param stat table 文件状态信息
---@param line_count number 缓冲区行数
---@return boolean
local function is_big_file(stat, line_count)
	local size_limit = 1 * 1024 * 1024 -- 1MB
	local line_limit = 20000 -- 20000 行
	return (stat and stat.size or 0) > size_limit or line_count > line_limit
end

--- 禁用大文件功能
local function disable_large_file_features(stat, line_count)
	if is_big_file(stat, line_count) then
		-- 使用 vim.bo 设置缓冲区选项
		vim.bo.foldmethod = "manual"
		vim.bo.syntax = "off"
		vim.bo.filetype = "off"
		vim.bo.undofile = false
		vim.bo.swapfile = false
		vim.bo.loadplugins = false
		-- 通知用户
		vim.notify("Large file detected. Disabling some features for better performance.")
	end
end

--- 恢复默认设置
local function restore_default_settings()
	vim.bo.foldmethod = "marker"
	vim.bo.syntax = "on"
	vim.bo.filetype = "on"
	vim.bo.undofile = true
	vim.bo.swapfile = true
	vim.bo.loadplugins = true
end

--- 根据文件类型或行数禁用插件
local function handle_plugin_for_large_file(file_type, line_count)
	if file_type == "log" or line_count > 5000 then
		vim.cmd("DisableHL") -- 假设插件有 DisableHL 命令
	else
		vim.cmd("EnableHL") -- 假设插件有 EnableHL 命令
	end
end

--- 自动命令设置
function M.setup()
	local group = vim.api.nvim_create_augroup("LargeFileHandling", { clear = true })
	-- 读取文件前处理
	vim.api.nvim_create_autocmd("BufReadPre", {
		group = group,
		pattern = "*",
		callback = function()
			local _, _, stat, line_count, file_type = get_buffer_info()
			disable_large_file_features(stat, line_count) -- 禁用大文件的相关设置
			handle_plugin_for_large_file(file_type, line_count) -- 根据文件类型或行数禁用插件
		end,
	})

	-- 读取文件后恢复设置
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		pattern = "*",
		callback = restore_default_settings, -- 恢复默认设置
	})
end

return M
