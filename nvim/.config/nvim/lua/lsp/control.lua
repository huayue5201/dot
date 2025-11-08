local M = {}

local manager, project_state, utils

local function ensure_modules()
	if not manager then
		manager = require("lsp.manager")
	end
	if not project_state then
		project_state = require("lsp.project_state")
	end
	if not utils then
		utils = require("lsp.utils")
	end
end

-- 统一错误处理函数
local function handle_lsp_error(operation, lsp_name, err, level)
	level = level or vim.log.levels.ERROR
	local message = string.format("LSP %s %s: %s", lsp_name, operation, tostring(err))
	vim.notify(message, level)
	return false, err
end

function M.stop_lsp()
	ensure_modules()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

	if not clients or vim.tbl_isempty(clients) then
		vim.notify("当前缓冲区没有活跃的 LSP 客户端", vim.log.levels.INFO)
		return
	end

	local lsp_names = vim.tbl_map(function(client)
		return client.name
	end, clients)

	vim.ui.select(lsp_names, { prompt = "  停止lsp " }, function(choice)
		if not choice then
			vim.notify("已取消停止操作", vim.log.levels.INFO)
			return
		end

		local success, err = manager.stop_lsp(choice, bufnr)
		if success then
			manager.set_lsp_state(choice, false)
			vim.notify("已停止 LSP: " .. choice, vim.log.levels.INFO)
		else
			handle_lsp_error("停止", choice, err)
		end
	end)
end

function M.start_lsp()
	ensure_modules()
	local disabled_lsps = {}

	for _, lsp_name in ipairs(utils.get_lsp_name()) do
		if not manager.is_lsp_enabled(lsp_name) then
			table.insert(disabled_lsps, lsp_name)
		end
	end

	if #disabled_lsps == 0 then
		vim.notify("所有支持的 LSP 客户端均已启动", vim.log.levels.INFO)
		return
	end

	vim.ui.select(disabled_lsps, { prompt = " 󰀚 启动lsp " }, function(choice)
		if not choice then
			vim.notify("已取消启动操作", vim.log.levels.INFO)
			return
		end

		local success, err = manager.start_lsp(choice)
		if success then
			manager.set_lsp_state(choice, true)
			vim.notify("已启动 LSP: " .. choice, vim.log.levels.INFO)
		else
			handle_lsp_error("启动", choice, err)
		end
	end)
end

-- =============================================
-- 缓冲区级 LSP 管理（程序化接口）
-- =============================================

function M.buffer_stop(lsp_names, bufnr)
	ensure_modules()
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 参数标准化
	if type(lsp_names) == "string" then
		lsp_names = { lsp_names }
	end

	if not lsp_names or #lsp_names == 0 then
		return false, "需要提供 LSP 名称"
	end

	local buffer_state = require("lsp.buffer_state")
	local stopped = 0

	for _, lsp_name in ipairs(lsp_names) do
		-- 分离客户端
		local clients = vim.lsp.get_active_clients({ name = lsp_name, bufnr = bufnr })

		for _, client in ipairs(clients) do
			pcall(vim.lsp.buf_detach_client, bufnr, client.id)
		end

		-- 设置缓冲区状态
		buffer_state.set_buffer_lsp_state(bufnr, lsp_name, false)
		stopped = stopped + 1
	end

	if stopped > 0 then
		vim.notify(string.format("已停止 %d 个 LSP", stopped), vim.log.levels.INFO)
	end

	return true
end

function M.buffer_start(lsp_names, bufnr)
	ensure_modules()
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 参数标准化
	if type(lsp_names) == "string" then
		lsp_names = { lsp_names }
	end

	if not lsp_names or #lsp_names == 0 then
		return false, "需要提供 LSP 名称"
	end

	local buffer_state = require("lsp.buffer_state")
	local started = 0

	for _, lsp_name in ipairs(lsp_names) do
		-- 清除缓冲区状态
		buffer_state.set_buffer_lsp_state(bufnr, lsp_name, nil)

		-- 重新启动 LSP
		local success, err = manager.start_lsp(lsp_name, bufnr)
		if success then
			started = started + 1
		else
			vim.notify(string.format("启动 %s 失败: %s", lsp_name, err), vim.log.levels.WARN)
		end
	end

	if started > 0 then
		vim.notify(string.format("已启动 %d 个 LSP", started), vim.log.levels.INFO)
	end

	return started > 0
end

-- =============================================
-- 便捷方法
-- =============================================

function M.buffer_stop_all(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
	if #clients == 0 then
		vim.notify("当前缓冲区没有 LSP 客户端", vim.log.levels.INFO)
		return
	end

	local lsp_names = {}
	for _, client in ipairs(clients) do
		table.insert(lsp_names, client.name)
	end

	return M.buffer_stop(lsp_names, bufnr)
end

function M.buffer_start_all(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buffer_state = require("lsp.buffer_state")
	local buffer_states = buffer_state.get_all_buffer_states(bufnr)

	local disabled_lsps = {}
	for lsp_name, enabled in pairs(buffer_states) do
		if enabled == false then
			table.insert(disabled_lsps, lsp_name)
		end
	end

	if #disabled_lsps == 0 then
		vim.notify("当前缓冲区没有禁用的 LSP", vim.log.levels.INFO)
		return true
	end

	return M.buffer_start(disabled_lsps, bufnr)
end

function M.restart_lsp()
	ensure_modules()
	local clients = vim.lsp.get_clients()

	-- 先停止所有客户端
	for _, client in ipairs(clients) do
		manager.stop_lsp(client.name)
	end
	-- 延迟重启
	vim.defer_fn(function()
		manager.start_eligible_lsps()
		vim.notify("LSP 客户端已重启", vim.log.levels.INFO)
	end, 500)
end

return M
