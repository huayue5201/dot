-- LSP 管理器模块
-- 负责 LSP 客户端生命周期管理、状态显示等核心业务逻辑
local M = {}

-- 引入独立模块
local large_file = require("lsp.large_file")
local project_state = require("lsp.project_state")

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

	-- 特殊 LSP 使用特殊处理
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.stop then
			return pcall(handler.stop, bufnr)
		end
		return false, "特殊 LSP 没有定义停止方法"
	end

	-- 标准 LSP 使用标准停止方法
	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	for _, client in ipairs(clients) do
		pcall(client.stop, client)
	end
	return true
end

-- 启动 LSP 客户端
function M.start_lsp(lsp_name, bufnr)
	bufnr = bufnr or 0

	-- 特殊 LSP 使用特殊处理
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.start then
			return pcall(handler.start, bufnr)
		end
		return false, "特殊 LSP 没有定义启动方法"
	end

	-- 标准 LSP 使用标准启动方法
	return pcall(vim.lsp.enable, lsp_name, true)
end

-- 检查 LSP 是否正在运行
function M.is_lsp_running(lsp_name, bufnr)
	bufnr = bufnr or 0

	-- 特殊 LSP 使用特殊检查方法
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.is_running then
			return pcall(handler.is_running, bufnr)
		end
		-- 对于没有定义检查方法的特殊 LSP，默认返回 true
		return true
	end

	-- 标准 LSP 使用标准检查方法
	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	return #clients > 0
end

-- =============================================
-- 大文件检测代理函数
-- =============================================

-- 停止大文件相关的 LSP
function M.stop_lsps_for_large_file(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" then
		return
	end

	-- 检查文件大小和行数
	local file_size = large_file.check_buffer_file_size(bufnr)
	local line_count = large_file.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return
	end

	local size_threshold = large_file.get_file_threshold()
	local line_threshold = large_file.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	-- 更新状态
	large_file.state.current_buffer = bufnr
	if not large_file.state.large_files[filename] then
		large_file.state.large_files[filename] = {
			size = file_size,
			lines = line_count,
			lsps_disabled = {},
		}
	end

	if is_large_file then
		-- 停止该缓冲区中所有需要检测的 LSP（但只处理在项目中启用的 LSP）
		local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
		local stopped_clients = {}

		for _, client in ipairs(clients) do
			-- 只有在项目中启用且配置了大文件检测的 LSP 才处理
			if project_state.is_lsp_enabled(client.name) and large_file.should_check_file_size(client.name) then
				-- 使用通用停止函数
				local success, err = M.stop_lsp(client.name, bufnr)
				if success then
					table.insert(stopped_clients, client.name)
					table.insert(large_file.state.large_files[filename].lsps_disabled, client.name)
				else
					vim.notify(string.format("停止 LSP %s 失败: %s", client.name, err), vim.log.levels.ERROR)
				end
			end
		end

		if #stopped_clients > 0 then
			local reasons = {}
			if is_large_by_size then
				table.insert(reasons, string.format("大小(%dMB)", math.floor(file_size / 1024 / 1024)))
			end
			if is_large_by_lines then
				table.insert(reasons, string.format("行数(%d行)", line_count))
			end

			vim.notify(
				string.format(
					"检测到大文件 (%s)，已禁用 LSP: %s",
					table.concat(reasons, ", "),
					table.concat(stopped_clients, ", ")
				),
				vim.log.levels.WARN
			)
		end
	else
		-- 如果是小文件，清除禁用状态
		local file_state = large_file.state.large_files[filename]
		if file_state and #file_state.lsps_disabled > 0 then
			-- 尝试重新启用之前禁用的 LSP
			for _, lsp_name in ipairs(file_state.lsps_disabled) do
				M.start_lsp(lsp_name, bufnr)
			end
			large_file.state.large_files[filename].lsps_disabled = {}
		end
	end
end

-- 重新启用大文件的 LSP（如果文件变小了）
function M.restart_lsps_for_small_file(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" then
		return
	end

	-- 同时检查文件大小和行数
	local file_size = large_file.check_buffer_file_size(bufnr)
	local line_count = large_file.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return
	end

	local size_threshold = large_file.get_file_threshold()
	local line_threshold = large_file.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	-- 如果文件不再是大文件，清除状态记录
	if not is_large_file then
		local file_state = large_file.state.large_files[filename]
		if file_state then
			large_file.state.large_files[filename].lsps_disabled = {}
		end
	end
end

-- 大文件检测相关代理函数
function M.should_check_file_size(lsp_name)
	return large_file.should_check_file_size(lsp_name)
end

function M.get_large_file_status(bufnr)
	return large_file.get_large_file_status(bufnr)
end

-- =============================================
-- 项目状态代理函数
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
	local utils = require("lsp.utils")
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
	local utils = require("lsp.utils")
	local active_clients = utils.get_active_lsps()

	-- 添加文件大小信息
	local file_info = M.get_large_file_status()

	print("=== LSP 状态概览 ===")
	print(string.format("项目: %s", project_name))

	if file_info.status ~= "unknown" then
		local large_file_msg = file_info.is_large_file and " (大文件 - LSP 可能被禁用)" or ""
		print(string.format("文件: %s, %s 行%s", file_info.size_mb, file_info.lines_count, large_file_msg))
	end
	print("")

	-- 显示项目状态配置
	if next(project_states) then
		print("项目 LSP 状态配置:")
		for lsp_name, state in pairs(project_states) do
			local status = state.enabled and "启用" or "禁用"
			local large_file_check = M.should_check_file_size(lsp_name) and " [大文件检测]" or ""
			local special_marker = M.is_special_lsp(lsp_name) and " [特殊LSP]" or ""
			print(string.format("  %s: %s%s%s", lsp_name, status, large_file_check, special_marker))
		end
		print("")
	end

	-- 显示活跃的 LSP 客户端
	if #active_clients > 0 then
		print(string.format("活跃的 LSP 服务器 (%d 个):", #active_clients))
		for i, client in ipairs(active_clients) do
			local state = project_states[client.name]
			local config_status = state and (state.enabled and "✓" or "✗") or "✓"
			local large_file_status = M.should_check_file_size(client.name) and " [大文件检测]" or ""
			local type_marker = M.is_special_lsp(client.name) and " [特殊]" or ""

			print(string.format("  %d. %s [%s]%s%s", i, client.name, config_status, large_file_status, type_marker))
			print(string.format("     根目录: %s", client.root_dir or "未设置"))
		end
	else
		print("当前没有活跃的 LSP 客户端")
	end
end

-- 显示详细的 LSP 信息
function M.show_lsp_info()
	local utils = require("lsp.utils")
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
	-- 管理器模块初始化
	-- 目前不需要特殊初始化操作
end

return M
