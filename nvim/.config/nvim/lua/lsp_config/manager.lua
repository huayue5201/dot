-- LSP 状态管理模块
-- 整合项目状态管理、状态信息展示等功能
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 项目状态管理
-- =============================================

-- 创建 JSON 存储实例（用于项目级 LSP 状态）
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
	auto_save = false,
})

-- 获取当前项目唯一标识
function M.get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 获取项目显示名
local function get_project_display_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 安全加载状态
function M.load_project_states()
	if state_store.get_all then
		return state_store:get_all()
	end
	return state_store:load()
end

-- 延迟保存状态
function M.save_project_states(states)
	state_store:save(states)
	vim.defer_fn(function()
		if state_store.flush then
			state_store:flush()
		end
	end, 100)
end

-- 检查特定 LSP 是否启用
function M.is_lsp_enabled(lsp_name)
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id]

	if not project_states or not project_states[lsp_name] then
		return true -- 默认启用
	end

	return project_states[lsp_name].enabled
end

-- 设置 LSP 启用状态
function M.set_lsp_state(lsp_name, enabled)
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()

	states[project_id] = states[project_id] or {}
	states[project_id][lsp_name] = {
		enabled = enabled,
		timestamp = os.time(),
	}

	M.save_project_states(states)

	vim.notify(string.format("LSP %s: %s", lsp_name, enabled and "已启用" or "已禁用"), vim.log.levels.INFO)
end

-- 获取当前项目所有 LSP 状态
function M.get_project_lsp_states()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	return states[project_id] or {}
end

-- =============================================
-- LSP 客户端管理
-- =============================================

-- 启动符合条件的 LSP
function M.start_eligible_lsps()
	local utils = require("lsp_config.utils")
	local lsp_names = utils.get_lsp_name()

	for _, lsp_name in ipairs(lsp_names) do
		if M.is_lsp_enabled(lsp_name) then
			local success, err = pcall(vim.lsp.enable, lsp_name, true)
			if not success then
				vim.notify(string.format("LSP 启动失败 %s: %s", lsp_name, err), vim.log.levels.ERROR)
			end
		end
	end
end

-- 停止特定 LSP
function M.stop_lsp_client(lsp_name)
	local clients = vim.lsp.get_clients({ name = lsp_name })
	for _, client in ipairs(clients) do
		client:stop()
	end
end

-- =============================================
-- 状态信息显示
-- =============================================

-- 显示 LSP 状态信息
function M.show_lsp_status()
	local project_name = get_project_display_name()
	local project_states = M.get_project_lsp_states()
	local utils = require("lsp_config.utils")
	local active_clients = utils.get_active_lsps()

	print("=== LSP 状态概览 ===")
	print(string.format("项目: %s", project_name))
	print("")

	-- 显示项目状态配置
	if next(project_states) then
		print("项目 LSP 状态配置:")
		for lsp_name, state in pairs(project_states) do
			local status = state.enabled and "启用" or "禁用"
			print(string.format("  %s: %s", lsp_name, status))
		end
		print("")
	end

	-- 显示活跃的 LSP 客户端
	if #active_clients > 0 then
		print(string.format("活跃的 LSP 服务器 (%d 个):", #active_clients))
		for i, client in ipairs(active_clients) do
			local state = project_states[client.name]
			local config_status = state and (state.enabled and "✓" or "✗") or "✓" -- 默认启用
			print(string.format("  %d. %s [%s]", i, client.name, config_status))
			print(string.format("     根目录: %s", client.root_dir or "未设置"))
		end
	else
		print("当前没有活跃的 LSP 客户端")
	end
end

-- 显示详细的 LSP 信息
function M.show_lsp_info()
	local utils = require("lsp_config.utils")
	local bufnr = vim.api.nvim_get_current_buf()
	local filetype = vim.bo[bufnr].filetype

	print("=== LSP 详细信息 ===")
	print(string.format("文件类型: %s", filetype))

	-- 显示当前缓冲区的 LSP 能力
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

-- 显示 LSP 诊断统计
function M.show_diagnostics_stats()
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)

	local stats = {
		error = 0,
		warn = 0,
		info = 0,
		hint = 0,
	}

	for _, diag in ipairs(diagnostics) do
		if diag.severity == vim.diagnostic.severity.ERROR then
			stats.error = stats.error + 1
		elseif diag.severity == vim.diagnostic.severity.WARN then
			stats.warn = stats.warn + 1
		elseif diag.severity == vim.diagnostic.severity.INFO then
			stats.info = stats.info + 1
		elseif diag.severity == vim.diagnostic.severity.HINT then
			stats.hint = stats.hint + 1
		end
	end

	print("=== 诊断统计 ===")
	print(string.format("错误: %d", stats.error))
	print(string.format("警告: %d", stats.warn))
	print(string.format("信息: %d", stats.info))
	print(string.format("提示: %d", stats.hint))
	print(string.format("总计: %d", #diagnostics))
end

-- =============================================
-- 模块初始化
-- =============================================

function M.setup()
	-- 初始化完成，不需要设置全局标志
end

return M
