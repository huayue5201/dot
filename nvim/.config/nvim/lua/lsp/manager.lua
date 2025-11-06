-- LSP 状态管理模块
-- 整合项目状态管理、进度显示、状态信息展示等功能
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 进度显示功能
-- =============================================

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local lsp_status_msg = ""
local is_lsp_loading = false
local redraw_scheduled = false

local function update_spinner()
	spinner_index = (spinner_index % #spinner_frames) + 1
end

local function schedule_redraw()
	if redraw_scheduled then
		return
	end
	redraw_scheduled = true
	vim.schedule(function()
		vim.cmd("redrawstatus")
		redraw_scheduled = false
	end)
end

-- 获取当前进度状态文本（供 statusline 使用）
function M.get_progress_status()
	if lsp_status_msg == "" then
		return ""
	end
	local spinner = spinner_frames[spinner_index]
	local max_len = 40 -- 最长保留的 LSP 消息长度
	local msg = lsp_status_msg
	if #msg > max_len then
		msg = msg:sub(1, max_len - 3) .. "..."
	end
	return spinner .. " " .. msg
end

-- 返回是否正在加载 LSP
function M.is_lsp_loading()
	return is_lsp_loading
end

-- =============================================
-- 项目状态管理
-- =============================================

-- 创建 JSON 存储实例（用于项目级 LSP 状态）
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
	auto_save = false, -- 采用延迟写入模式，避免频繁 I/O
})

-- 获取当前项目唯一标识（基于路径哈希）
local function get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 获取项目显示名（仅用于提示）
local function get_project_display_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 安全加载状态
local function load_project_states()
	if state_store.get_all then
		return state_store:get_all()
	end
	return state_store:load()
end

-- 延迟保存状态
local function save_project_states(states)
	state_store:save(states)
	vim.defer_fn(function()
		if state_store.flush then
			state_store:flush()
		end
	end, 100)
end

-- 获取当前项目 LSP 启用状态（默认为启用）
function M.get_lsp_state()
	local project_id = get_current_project_id()
	local states = load_project_states()
	local state = states[project_id]
	return state == nil or state.enabled
end

-- 设置当前项目的 LSP 启用 / 禁用状态
function M.set_lsp_state(enabled)
	local project_id = get_current_project_id()
	local project_name = get_project_display_name()
	local states = load_project_states()

	local utils = require("lsp.utils")
	local lsp_name = utils.get_lsp_name()

	if not lsp_name then
		vim.notify("当前缓冲区未找到活跃的 LSP 客户端", vim.log.levels.WARN)
		return
	end

	if type(lsp_name) == "table" then
		lsp_name = table.concat(lsp_name, ", ")
	end

	-- 状态未变化则跳过写入
	if states[project_id] and states[project_id].enabled == enabled then
		return
	end

	-- 更新状态缓存
	states[project_id] = {
		enabled = enabled,
		lsp_name = lsp_name,
		timestamp = os.time(),
	}

	save_project_states(states)
	vim.g.lsp_enabled = enabled

	vim.notify(
		string.format("LSP %s - 项目: %s [%s]", enabled and "已启用" or "已禁用", project_name, lsp_name),
		vim.log.levels.INFO
	)
end

-- 切换当前项目的 LSP 状态
function M.toggle_lsp_state()
	local current_state = M.get_lsp_state()
	M.set_lsp_state(not current_state)
end

-- =============================================
-- 状态信息显示
-- =============================================

-- 增强的 LSP 状态显示函数（合并两个命令的功能）
function M.show_lsp_status()
	local enabled = M.get_lsp_state()
	local status = enabled and "启用" or "禁用"
	local project_name = get_project_display_name()

	print("=== LSP 状态概览 ===")
	print(string.format("项目: %s", project_name))
	print(string.format("状态: %s", status))
	print("")

	-- 显示活跃的 LSP 客户端
	local utils = require("lsp.utils")
	local active_clients = utils.get_active_lsps()

	if #active_clients > 0 then
		print(string.format("活跃的 LSP 服务器 (%d 个):", #active_clients))
		for i, client in ipairs(active_clients) do
			print(string.format("  %d. %s", i, client.name))
			print(string.format("     根目录: %s", client.root_dir or "未设置"))
			print(string.format("     客户端ID: %s", client.id))
		end
	else
		print("当前没有活跃的 LSP 客户端")
	end

	-- 显示诊断统计摘要
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)
	if #diagnostics > 0 then
		print("")
		print(string.format("当前缓冲区诊断: %d 个问题", #diagnostics))
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

	-- 显示进度状态
	local progress_status = M.get_progress_status()
	if progress_status ~= "" then
		print(string.format("LSP 进度: %s", progress_status))
	end

	-- 显示项目信息
	local project_states = load_project_states()
	print(string.format("项目状态缓存: %d 个项目", vim.tbl_count(project_states)))
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
	-- 设置 LSP 进度处理器
	vim.api.nvim_create_autocmd("LspProgress", {
		callback = function(args)
			local val = args.data.params.value
			local kind = val.kind or ""
			local token = val.token or ""
			local title = val.title or ""
			local message = val.message or ""

			-- 过滤掉不需要显示的通知
			if token == "rustAnalyzer/cargoWatcher" then
				return
			end

			local msg = title
			if message ~= "" then
				msg = msg .. ": " .. message
			end

			if kind == "begin" or kind == "report" then
				lsp_status_msg = msg
				is_lsp_loading = true
			elseif kind == "end" then
				lsp_status_msg = ""
				is_lsp_loading = false
			end

			schedule_redraw()
		end,
	})

	-- 定时更新 spinner 动画
	local spinner_timer = vim.loop.new_timer()
	spinner_timer:start(
		0,
		120,
		vim.schedule_wrap(function()
			update_spinner()
			if lsp_status_msg ~= "" then
				schedule_redraw()
			end
		end)
	)

	-- 初始化项目 LSP 状态
	M.init()
end

-- 初始化当前项目 LSP 状态（启动或切换项目时调用）
function M.init()
	local enabled = M.get_lsp_state()
	vim.g.lsp_enabled = enabled
end

return M
