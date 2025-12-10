local M = {}

local utils = require("lsp-config.lsp_utils")

-- =========================================================
-- 配置选项
-- =========================================================
M.config = {
	-- Spinner 配置
	spinner_frames = { "", "", "", "", "", "" },
	spinner_interval = 150, -- 毫秒
	spinner_width = 2, -- 固定宽度

	-- 要忽略的 LSP 客户端
	ignore_clients = {
		"ruff",
		"ruff_lsp",
		"eslint",
		"copilot",
	},

	-- 诊断显示配置
	show_diagnostics = true,

	-- 高亮组
	highlight_group = "LspHighlight",

	-- 数字图标映射
	num_icons = {
		[1] = "󰼏",
		[2] = "󰎨",
		[3] = "󰎫",
		[4] = "󰼒",
		[5] = "󰎯",
		[6] = "󰼔",
		[7] = "󰼕",
		[8] = "󰼖",
		[9] = "󰼗",
		[10] = "󰿪",
	},
}

-- =========================================================
-- 初始化高亮组
-- =========================================================
vim.api.nvim_set_hl(0, "LspHighlight", { fg = "#fffff0", bold = true })

-- =========================================================
-- 动态 LSP Spinner
-- =========================================================
local spinner_index = 1
local spinner_active = false
local active_tasks = 0 -- 活动任务计数器
local spinner_timer = nil
local last_spinner = ""
local spinner_update_scheduled = false

-- 诊断级别配置
local DIAGNOSTIC_SEVERITY = {
	[vim.diagnostic.severity.ERROR] = {
		icon = utils.icons.diagnostic.ERROR,
		hl = "DiagnosticError",
	},
	[vim.diagnostic.severity.WARN] = {
		icon = utils.icons.diagnostic.WARN,
		hl = "DiagnosticWarn",
	},
	[vim.diagnostic.severity.INFO] = {
		icon = utils.icons.diagnostic.INFO,
		hl = "DiagnosticInfo",
	},
	[vim.diagnostic.severity.HINT] = {
		icon = utils.icons.diagnostic.HINT,
		hl = "DiagnosticHint",
	},
}

-- =========================================================
-- Spinner 管理函数
-- =========================================================
local function schedule_spinner_update()
	if not spinner_update_scheduled and spinner_active then
		spinner_update_scheduled = true
		vim.defer_fn(function()
			spinner_update_scheduled = false
			-- 只在 spinner 图标改变时重绘
			local current_spinner = M.config.spinner_frames[spinner_index]
			if current_spinner ~= last_spinner then
				last_spinner = current_spinner
				vim.cmd("redrawstatus")
			end
		end, math.max(100, M.config.spinner_interval / 2)) -- 最小间隔 100ms
	end
end

local function spinner_start()
	active_tasks = active_tasks + 1

	if active_tasks == 1 and not spinner_active then
		spinner_active = true
		spinner_index = 1

		-- 创建并启动定时器
		spinner_timer = vim.loop.new_timer()
		spinner_timer:start(
			0,
			M.config.spinner_interval,
			vim.schedule_wrap(function()
				spinner_index = (spinner_index % #M.config.spinner_frames) + 1
				schedule_spinner_update()
			end)
		)
	end
end

local function spinner_stop()
	active_tasks = math.max(0, active_tasks - 1)

	if active_tasks == 0 and spinner_active then
		spinner_active = false

		if spinner_timer then
			spinner_timer:stop()
			spinner_timer:close()
			spinner_timer = nil
		end

		-- 停止后刷新一次状态栏，清除 spinner
		vim.cmd("redrawstatus")
	end
end

local function spinner_icon()
	if not spinner_active then
		return ""
	end

	-- 使用格式化的字符串确保固定宽度
	local frame = M.config.spinner_frames[spinner_index]
	return string.format("%-" .. M.config.spinner_width .. "s", frame)
end

-- =========================================================
-- 自动监听 LSP 任务（LspProgress）
-- =========================================================
local active_progress_tokens = {} -- 使用 token 跟踪多个任务

vim.api.nvim_create_autocmd("LspProgress", {
	callback = function(ev)
		local val = ev.data.params.value

		-- 使用 token 来唯一标识任务
		local token = val.token or tostring(val.workDoneToken or val.title)

		if val.kind == "begin" then
			-- 记录这个 token 的任务开始了
			active_progress_tokens[token] = true
			spinner_start()
		elseif val.kind == "end" then
			-- 标记这个 token 的任务结束
			active_progress_tokens[token] = nil

			-- 检查是否还有活动的任务
			local has_active = false
			for _, _ in pairs(active_progress_tokens) do
				has_active = true
				break
			end

			if not has_active then
				spinner_stop()
			end
		end
	end,
})

-- =========================================================
-- LSP 客户端显示函数
-- =========================================================
function M.lsp_clients()
	local ok, buf_clients = pcall(vim.lsp.get_clients, { bufnr = vim.api.nvim_get_current_buf() })

	if not ok or vim.tbl_isempty(buf_clients) then
		return "%#" .. M.config.highlight_group .. "#󰼎 " .. "%*"
	end

	-- 客户端优先级配置
	local client_priority = {
		-- 默认：不在黑名单中的客户端最高优先级(101)
		-- 黑名单客户端可以设置0-100的优先级
		-- 0或负数：不显示为名字
		["ruff"] = 30,
		["ruff_lsp"] = 30,
		["eslint"] = 40,
		["copilot"] = 80,
	}

	-- 计算优先级和计数
	local clients_with_priority = {}
	local total_clients = 0

	for _, client in ipairs(buf_clients) do
		total_clients = total_clients + 1

		-- 获取客户端优先级（不在优先级表中的设为101）
		local priority = client_priority[client.name] or 101

		table.insert(clients_with_priority, {
			client = client,
			priority = priority,
		})
	end

	-- 按优先级降序排序
	table.sort(clients_with_priority, function(a, b)
		return a.priority > b.priority
	end)

	-- 选择优先级最高且大于0的客户端作为主客户端
	local main_client = nil
	for _, item in ipairs(clients_with_priority) do
		if item.priority > 0 then
			main_client = item.client
			break
		end
	end

	-- 如果没有可显示名字的客户端
	if not main_client then
		-- 获取图标（超过10个显示"󰿪+"）
		local icon
		if total_clients > 10 then
			icon = "󰿪+"
		else
			icon = M.config.num_icons[total_clients] or "󰿪"
		end

		local spin = spinner_icon()
		return string.format("%s%s", "%#" .. M.config.highlight_group .. "#" .. icon .. "%*", spin)
	end

	-- 获取图标（超过10个显示"󰿪+"）
	local icon
	if total_clients > 10 then
		icon = "󰿪+"
	else
		icon = M.config.num_icons[total_clients] or "󰿪"
	end

	-- 获取动态 spinner
	local spin = spinner_icon()

	return string.format(
		"%s %s. %s",
		"%#" .. M.config.highlight_group .. "#" .. icon .. "%*",
		main_client.name,
		spin
	)
end

-- =========================================================
-- 诊断统计函数
-- =========================================================
function M.lsp_diagnostics()
	if not M.config.show_diagnostics then
		return ""
	end

	local ok, counts = pcall(vim.diagnostic.count, 0)
	if not ok then
		return ""
	end

	local parts = {}
	local order = {
		vim.diagnostic.severity.ERROR,
		vim.diagnostic.severity.WARN,
		vim.diagnostic.severity.INFO,
		vim.diagnostic.severity.HINT,
	}

	for _, sev in ipairs(order) do
		local count = counts[sev] or 0
		if count > 0 then
			local data = DIAGNOSTIC_SEVERITY[sev]
			if data then
				table.insert(parts, "%#" .. data.hl .. "#" .. data.icon .. count .. "%*")
			end
		end
	end

	if #parts == 0 then
		return ""
	end

	return table.concat(parts, " ")
end

-- =========================================================
-- 总 LSP 显示函数（修复：包含客户端和诊断信息）
-- =========================================================
function M.lsp()
	local client_part = M.lsp_clients()
	local diag_part = M.lsp_diagnostics()

	-- 如果诊断部分不为空，则拼接它们
	if diag_part ~= "" then
		return string.format("%s %s", client_part, diag_part)
	else
		return client_part
	end
end

-- =========================================================
-- 清理函数（防止内存泄漏）
-- =========================================================
function M.cleanup()
	-- 清理所有活动任务
	active_progress_tokens = {}
	active_tasks = 0

	-- 停止并关闭定时器
	if spinner_timer then
		spinner_timer:stop()
		spinner_timer:close()
		spinner_timer = nil
	end

	spinner_active = false
	spinner_update_scheduled = false
end

-- =========================================================
-- 配置更新函数
-- =========================================================
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
end

-- =========================================================
-- 自动清理（Vim退出时）
-- =========================================================
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		M.cleanup()
	end,
})

return M
