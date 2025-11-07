-- LSP 状态管理模块
-- 整合项目状态管理、状态信息展示等功能
local json_store = require("utils.json_store")

local M = {}
-- =============================================
-- 通用特殊 LSP 管理（精简版）
-- =============================================

M.special_lsps = {
	-- GitHub Copilot (使用 copilot.vim)
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

-- 检查是否为特殊 LSP
function M.is_special_lsp(lsp_name)
	return M.special_lsps[lsp_name] ~= nil
end

-- 通用 LSP 停止函数
function M.stop_lsp(lsp_name, bufnr)
	bufnr = bufnr or 0

	-- 如果是特殊 LSP，使用特殊处理
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.stop then
			return pcall(handler.stop, bufnr)
		end
		return false, "特殊 LSP 没有定义停止方法"
	end

	-- 标准 LSP，使用标准停止方法
	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	for _, client in ipairs(clients) do
		pcall(client.stop, client)
	end
	return true
end

-- 通用 LSP 启动函数
function M.start_lsp(lsp_name, bufnr)
	bufnr = bufnr or 0

	-- 如果是特殊 LSP，使用特殊处理
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.start then
			return pcall(handler.start, bufnr)
		end
		return false, "特殊 LSP 没有定义启动方法"
	end

	-- 标准 LSP，使用标准启动方法
	return pcall(vim.lsp.enable, lsp_name, true)
end

-- 检查 LSP 是否正在运行
function M.is_lsp_running(lsp_name, bufnr)
	bufnr = bufnr or 0

	-- 如果是特殊 LSP，使用特殊检查方法
	if M.is_special_lsp(lsp_name) then
		local handler = M.special_lsps[lsp_name]
		if handler and handler.is_running then
			return pcall(handler.is_running, bufnr)
		end
		-- 对于没有定义检查方法的特殊 LSP，默认返回 true
		return true
	end

	-- 标准 LSP，使用标准检查方法
	local clients = vim.lsp.get_clients({ name = lsp_name, bufnr = bufnr })
	return #clients > 0
end

-- =============================================
-- 大文件检测配置
-- =============================================
M.large_file_config = {
	-- 启用大文件检测的 LSP 列表
	enabled_lsps = {
		"vtsls", -- TypeScript/JavaScript 语言服务器
	},

	-- 默认文件大小阈值 (3MB)
	default_threshold = 3 * 1024 * 1024,

	-- 默认行数阈值 (50000 行)
	default_line_threshold = 50000,
}

-- 当前已检测到的大文件状态
M._large_file_state = {
	current_buffer = nil,
	large_files = {}, -- 存储已检测到的大文件路径和对应的 LSP 状态
}

-- 获取行数阈值
function M.get_line_threshold()
	return M.large_file_config.default_line_threshold
end

-- 检查当前缓冲区行数
function M.check_buffer_line_count(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end
	return vim.api.nvim_buf_line_count(bufnr)
end

-- 在 manager.lua 中添加以下缺失的函数

-- 检查特定 LSP 是否启用大文件检测
function M.should_check_file_size(lsp_name)
	return vim.tbl_contains(M.large_file_config.enabled_lsps, lsp_name)
end

-- 获取文件大小阈值
function M.get_file_threshold()
	return M.large_file_config.default_threshold
end

-- 检查当前缓冲区文件大小
function M.check_buffer_file_size(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" or not vim.loop.fs_stat then
		return nil -- 新文件或无法获取文件信息
	end

	local stat = vim.loop.fs_stat(filename)
	return stat and stat.size or nil
end

-- 判断特定 LSP 是否因文件过大需要禁用（同时考虑大小和行数）
function M.should_disable_lsp_due_to_size(lsp_name, bufnr)
	-- 首先检查该 LSP 是否在项目中被禁用（JSON存储中的状态）
	if not M.is_lsp_enabled(lsp_name) then
		return false -- 已经在JSON中被禁用，不需要大文件检测
	end

	-- 然后检查该 LSP 是否启用大文件检测
	if not M.should_check_file_size(lsp_name) then
		return false
	end

	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	-- 如果无法获取文件大小和行数，默认启用
	if not file_size and not line_count then
		return false
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	if is_large_file then
		local reasons = {}
		if is_large_by_size then
			table.insert(reasons, string.format("大小(%dMB)", math.floor(file_size / 1024 / 1024)))
		end
		if is_large_by_lines then
			table.insert(reasons, string.format("行数(%d行)", line_count))
		end

		vim.notify(
			string.format("检测到大文件 (%s)，已禁用 %s LSP", table.concat(reasons, ", "), lsp_name),
			vim.log.levels.WARN
		)
	end

	return is_large_file
end

-- 停止缓冲区中的大文件 LSP（增强版）
function M.stop_lsps_for_large_file(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" then
		return
	end

	-- 检查文件大小和行数
	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	-- 更新状态
	M._large_file_state.current_buffer = bufnr
	if not M._large_file_state.large_files[filename] then
		M._large_file_state.large_files[filename] = {
			size = file_size,
			lines = line_count,
			lsps_disabled = {},
		}
	end

	if is_large_file then
		-- 停止该缓冲区中所有需要检测的 LSP（但只处理在JSON中启用的LSP）
		local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
		local stopped_clients = {}

		for _, client in ipairs(clients) do
			-- 只有在JSON中启用且配置了大文件检测的LSP才处理
			if M.is_lsp_enabled(client.name) and M.should_check_file_size(client.name) then
				-- 使用通用停止函数
				local success, err = M.stop_lsp(client.name, bufnr)
				if success then
					table.insert(stopped_clients, client.name)
					table.insert(M._large_file_state.large_files[filename].lsps_disabled, client.name)
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
		local file_state = M._large_file_state.large_files[filename]
		if file_state and #file_state.lsps_disabled > 0 then
			-- 尝试重新启用之前禁用的 LSP
			for _, lsp_name in ipairs(file_state.lsps_disabled) do
				M.start_lsp(lsp_name, bufnr)
			end
			M._large_file_state.large_files[filename].lsps_disabled = {}
		end
	end
end

-- 获取大文件状态信息（增强版）
function M.get_large_file_status(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return { status = "unknown" }
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	local file_state = M._large_file_state.large_files[filename]
	local disabled_lsps = file_state and file_state.lsps_disabled or {}

	local status_details = {}
	if is_large_by_size then
		table.insert(status_details, "文件大小过大")
	end
	if is_large_by_lines then
		table.insert(status_details, "文件行数过多")
	end

	return {
		status = is_large_file and "large" or "normal",
		size = file_size,
		lines = line_count,
		size_mb = file_size and string.format("%.2fMB", file_size / 1024 / 1024) or "未知",
		lines_count = line_count and tostring(line_count) or "未知",
		threshold_mb = string.format("%.2fMB", size_threshold / 1024 / 1024),
		threshold_lines = tostring(line_threshold),
		disabled_lsps = disabled_lsps,
		is_large_file = is_large_file,
		status_details = status_details,
		is_large_by_size = is_large_by_size,
		is_large_by_lines = is_large_by_lines,
	}
end

-- 重新启用大文件的 LSP（如果文件变小了）
function M.restart_lsps_for_small_file(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" then
		return
	end

	-- 同时检查文件大小和行数
	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	-- 如果文件不再是大文件，清除状态记录
	if not is_large_file then
		local file_state = M._large_file_state.large_files[filename]
		if file_state then
			M._large_file_state.large_files[filename].lsps_disabled = {}
		end
	end
end

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
-- 启动符合条件的 LSP（增强版）
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
	local project_name = get_project_display_name()
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
	-- 初始化完成，不需要设置全局标志
end

return M
