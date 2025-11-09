-- lua/lsp/control.lua
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

-- =============================================
-- 统一的 LSP 管理
-- =============================================

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

	vim.ui.select(lsp_names, { prompt = "  停止LSP " }, function(choice)
		if not choice then
			vim.notify("已取消停止操作", vim.log.levels.INFO)
			return
		end

		local success, err = manager.stop_lsp(choice, bufnr)
		if success then
			-- 记录缓冲区级状态
			project_state.set_buffer_lsp_state(bufnr, choice, false)
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
		if not project_state.is_lsp_enabled_for_buffer(lsp_name) then
			table.insert(disabled_lsps, lsp_name)
		end
	end

	if #disabled_lsps == 0 then
		vim.notify("所有支持的 LSP 客户端均已启动", vim.log.levels.INFO)
		return
	end

	vim.ui.select(disabled_lsps, { prompt = " 󰀚 启动LSP " }, function(choice)
		if not choice then
			vim.notify("已取消启动操作", vim.log.levels.INFO)
			return
		end

		local success, err = manager.start_lsp(choice)
		if success then
			-- 记录缓冲区级状态
			project_state.set_buffer_lsp_state(0, choice, true)
			vim.notify("已启动 LSP: " .. choice, vim.log.levels.INFO)
		else
			handle_lsp_error("启动", choice, err)
		end
	end)
end

-- =============================================
-- 项目级 LSP 管理（智能排除冲突缓冲区）
-- =============================================

function M.project_stop_lsp()
	ensure_modules()
	local lsp_names = utils.get_lsp_name()

	if #lsp_names == 0 then
		vim.notify("当前文件类型没有支持的 LSP", vim.log.levels.INFO)
		return
	end

	vim.ui.select(lsp_names, { prompt = "  停止项目LSP " }, function(choice)
		if not choice then
			vim.notify("已取消停止操作", vim.log.levels.INFO)
			return
		end

		-- 设置项目级状态
		project_state.set_lsp_state(choice, false)

		-- 获取需要停止的缓冲区列表（排除有冲突的）
		local eligible_buffers = project_state.get_buffers_for_project_operation(choice, false)

		-- 停止符合条件的缓冲区
		local stopped_count = 0
		for _, buffer_key in ipairs(eligible_buffers) do
			local bufnr
			if buffer_key:match("^buffer_%d+$") then
				bufnr = tonumber(buffer_key:match("buffer_(%d+)"))
			else
				bufnr = vim.fn.bufnr(buffer_key)
			end

			if bufnr and bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
				local success, err = manager.stop_lsp(choice, bufnr)
				if success then
					stopped_count = stopped_count + 1
				end
			end
		end

		if stopped_count > 0 then
			vim.notify(
				string.format("已在 %d 个缓冲区停止 LSP: %s", stopped_count, choice),
				vim.log.levels.INFO
			)
		else
			vim.notify(string.format("LSP %s 已在项目中禁用", choice), vim.log.levels.INFO)
		end
	end)
end

function M.project_start_lsp()
	ensure_modules()
	local lsp_names = utils.get_lsp_name()

	if #lsp_names == 0 then
		vim.notify("当前文件类型没有支持的 LSP", vim.log.levels.INFO)
		return
	end

	vim.ui.select(lsp_names, { prompt = " 󰀚 启动项目LSP " }, function(choice)
		if not choice then
			vim.notify("已取消启动操作", vim.log.levels.INFO)
			return
		end

		-- 设置项目级状态
		project_state.set_lsp_state(choice, true)

		-- 获取需要启动的缓冲区列表（排除有冲突的）
		local eligible_buffers = project_state.get_buffers_for_project_operation(choice, true)

		-- 启动符合条件的缓冲区
		local started_count = 0
		for _, buffer_key in ipairs(eligible_buffers) do
			local bufnr
			if buffer_key:match("^buffer_%d+$") then
				bufnr = tonumber(buffer_key:match("buffer_(%d+)"))
			else
				bufnr = vim.fn.bufnr(buffer_key)
			end

			if bufnr and bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
				local success, err = manager.start_lsp(choice, bufnr)
				if success then
					started_count = started_count + 1
				end
			end
		end

		if started_count > 0 then
			vim.notify(
				string.format("已在 %d 个缓冲区启动 LSP: %s", started_count, choice),
				vim.log.levels.INFO
			)
		else
			vim.notify(string.format("LSP %s 已在项目中启用", choice), vim.log.levels.INFO)
		end
	end)
end

-- =============================================
-- 便捷方法
-- =============================================

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
