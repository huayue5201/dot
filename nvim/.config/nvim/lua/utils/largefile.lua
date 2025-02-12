-- utils/largerfile.lua
local M = {}

--- 获取缓冲区信息
---@return number, string, table, number, string
local function get_buffer_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local stat = vim.fn.stat(bufname) -- 使用 vim.fn.stat 来代替 vim.loop.fs_stat
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	-- 使用 nvim_get_option_value 替代 nvim_buf_get_option
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

--- 处理大文件时禁用一些功能
local function disable_large_file_features()
	-- 直接调用 get_buffer_info，不再使用 bufnr 变量
	local _, _, stat, line_count, _ = get_buffer_info()
	if is_big_file(stat, line_count) then
		local options = {
			foldmethod = "manual", -- 禁用自动折叠
			syntax = "off", -- 禁用语法高亮
			filetype = "off", -- 禁用文件类型检测
			undofile = false, -- 禁用撤销文件
			swapfile = false, -- 禁用交换文件
			loadplugins = false, -- 禁用插件加载
		}

		-- 使用 vim.bo 设置缓冲区选项
		for key, value in pairs(options) do
			vim.bo[key] = value
		end
		-- 通知用户
		vim.notify("Large file detected. Disabling some features for better performance.")
	end
end

--- 启用默认设置
local function restore_default_settings()
	-- 直接调用 get_buffer_info，不再使用 bufnr 变量
	local options = {
		foldmethod = "marker", -- 恢复默认折叠方式
		syntax = "on", -- 启用语法高亮
		filetype = "on", -- 启用文件类型检测
		undofile = true, -- 启用撤销文件
		swapfile = true, -- 启用交换文件
		loadplugins = true, -- 启用插件加载
	}

	-- 使用 vim.bo 设置缓冲区选项
	for key, value in pairs(options) do
		vim.bo[key] = value
	end
end

--- 插件控制逻辑（根据文件类型或行数禁用/启用插件）
local function handle_plugin_for_large_file()
	local _, _, _, line_count, file_type = get_buffer_info()

	-- 如果是日志文件或文件行数超过 5000，禁用插件
	if file_type == "log" or line_count > 5000 then
		vim.cmd("DisableHL") -- 假设插件有 DisableHL 命令
	else
		vim.cmd("EnableHL") -- 假设插件有 EnableHL 命令
	end
end

--- 自动命令设置
function M.setup()
	local group = vim.api.nvim_create_augroup("LargeFileHandling", { clear = true })

	-- 在文件读取之前处理大文件
	vim.api.nvim_create_autocmd("BufReadPre", {
		group = group,
		pattern = "*",
		callback = function()
			disable_large_file_features() -- 禁用大文件的相关设置
			handle_plugin_for_large_file() -- 根据文件类型或行数禁用插件
		end,
	})

	-- 在文件读取之后恢复设置
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		pattern = "*",
		callback = function()
			restore_default_settings() -- 恢复默认设置
		end,
	})
end

return M
