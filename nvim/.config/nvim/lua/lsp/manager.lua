-- LSP 管理器模块
-- 负责 LSP 客户端生命周期管理、状态显示等核心业务逻辑
local M = {}

-- 引入项目状态模块
local project_state = require("lsp.project_state")
local utils = require("lsp.utils")

-- =============================================
-- 特殊 LSP 处理配置
-- =============================================

M.special_lsps = {
	-- GitHub Copilot 特殊处理
	["copilot"] = {
		stop = function(bufnr)
			-- 尝试多种停止方式
			local success, _ = pcall(vim.cmd, "Copilot disable")
			if not success then
				pcall(vim.cmd, "Copilot stop")
			end
			return success
		end,
		start = function(bufnr)
			return pcall(vim.cmd, "Copilot enable")
		end,
		is_running = function(bufnr)
			return vim.g.copilot_enabled or false
		end,
	},
}

-- =============================================
-- LSP 客户端生命周期管理
-- =============================================

-- 检查是否为特殊 LSP
function M.is_special_lsp(lsp_name)
	return M.special_lsps[lsp_name] ~= nil
end

-- 停止 LSP 客户端
function M.stop_lsp(lsp_name, bufnr)
	bufnr = bufnr or 0

	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.stop then
			return pcall(handler.stop, bufnr)
		end
		return false, "特殊 LSP 没有定义停止方法"
	end

	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	for _, client in ipairs(clients) do
		pcall(client.stop, client)
	end
	return true
end

-- 启动 LSP 客户端
function M.start_lsp(lsp_name, bufnr)
	bufnr = bufnr or 0

	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.start then
			return pcall(handler.start, bufnr)
		end
		return false, "特殊 LSP 没有定义启动方法"
	end

	return pcall(vim.lsp.enable, lsp_name, true)
end

-- 检查 LSP 是否正在运行
function M.is_lsp_running(lsp_name, bufnr)
	bufnr = bufnr or 0

	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.is_running then
			return pcall(handler.is_running, bufnr)
		end
		return true
	end

	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	return #clients > 0
end

-- =============================================
-- 项目状态管理（直接使用 project_state，避免冗余代理）
-- =============================================

function M.is_lsp_enabled(lsp_name)
	return project_state.is_lsp_enabled(lsp_name)
end

function M.set_lsp_state(lsp_name, enabled)
	project_state.set_lsp_state(lsp_name, enabled)
end

function M.get_project_lsp_states()
	return project_state.get_project_lsp_states()
end

-- =============================================
-- LSP 启动管理
-- =============================================

-- 启动符合条件的 LSP
function M.start_eligible_lsps()
	local lsp_names = utils.get_lsp_name()

	for _, lsp_name in ipairs(lsp_names) do
		if M.is_lsp_enabled(lsp_name) then
			local success, err = M.start_lsp(lsp_name)
			if not success then
				vim.notify(string.format("LSP 启动失败 %s: %s", lsp_name, err), vim.log.levels.ERROR)
			end
		end
	end
end

-- =============================================
-- 状态信息显示
-- =============================================

-- 显示 LSP 状态信息
function M.show_lsp_status()
	local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	local project_states = M.get_project_lsp_states()
	local active_clients = utils.get_active_lsps()

	print("=== LSP 状态概览 ===")
	print(string.format("项目: %s\n", project_name))

	-- 显示项目状态配置
	if next(project_states) then
		print("项目 LSP 状态配置:")
		for lsp_name, state in pairs(project_states) do
			local status = state.enabled and "启用" or "禁用"
			local special_marker = M.is_special_lsp(lsp_name) and " [特殊LSP]" or ""
			print(string.format("  %s: %s%s", lsp_name, status, special_marker))
		end
		print("")
	end

	-- 显示活跃的 LSP 客户端
	if #active_clients > 0 then
		print(string.format("活跃的 LSP 服务器 (%d 个):", #active_clients))
		for i, client in ipairs(active_clients) do
			local state = project_states[client.name]
			local config_status = state and (state.enabled and "✓" or "✗") or "✓"
			local type_marker = M.is_special_lsp(client.name) and " [特殊]" or ""

			print(string.format("  %d. %s [%s]%s", i, client.name, config_status, type_marker))
			print(string.format("     根目录: %s", client.root_dir or "未设置"))
		end
	else
		print("当前没有活跃的 LSP 客户端")
	end
end

-- 显示详细的 LSP 信息
function M.show_lsp_info()
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype

	print("=== LSP 详细信息 ===")
	print(string.format("文件类型: %s", filetype))

	local capabilities = utils.get_buffer_capabilities(bufnr)
	if next(capabilities) then
		print("LSP 功能支持:")
		for client_name, caps in pairs(capabilities) do
			print(string.format("  %s:", client_name))
			for cap_name, supported in pairs(caps) do
				local status = supported and "✓" or "✗"
				print(string.format("    %s %s", status, cap_name))
			end
		end
	else
		print("当前缓冲区没有 LSP 客户端")
	end
end

return M
