local M = {}

local icons = require("lsp_ext.icons")

-- =========================================================
-- 配置选项
-- =========================================================
M.config = {
	-- Spinner 配置
	spinner_frames = { "", "", "", "", "", "" },
	-- spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	spinner_interval = 150, -- 毫秒
	spinner_width = 2, -- 固定宽度

	-- 诊断显示配置
	show_diagnostics = true,

	-- 高亮组
	highlight_group = "LspHighlight",
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
local spinner_timer = nil
local last_spinner = ""
local spinner_update_scheduled = false

-- 诊断级别配置
local DIAGNOSTIC_SEVERITY = {
	[vim.diagnostic.severity.ERROR] = {
		icon = icons.ERROR,
		hl = "DiagnosticError",
	},
	[vim.diagnostic.severity.WARN] = {
		icon = icons.WARN,
		hl = "DiagnosticWarn",
	},
	[vim.diagnostic.severity.INFO] = {
		icon = icons.INFO,
		hl = "DiagnosticInfo",
	},
	[vim.diagnostic.severity.HINT] = {
		icon = icons.HINT,
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
				vim.api.nvim_exec_autocmds("User", { pattern = "LspStatusSpinner" })
			end
		end, math.max(100, M.config.spinner_interval / 2)) -- 最小间隔 100ms
	end
end

---spinner 是否该转，完全由 active_progress 是否为空决定（幂等开关）。
---早期版本用 active_tasks 计数器：begin 就 +1，但只有「token 集合清空」时才 -1，
---于是两个进度任务重叠（begin A、begin B、end A、end B）后计数器停在 1，
---spinner 永远转不停 —— 表现为“LSP 一直处于启动中”。
---@param active boolean
local function spinner_set_active(active)
	if active == spinner_active then
		return
	end
	spinner_active = active

	if active then
		spinner_index = 1
		last_spinner = "" -- 避免与上轮最后一帧相同而不重绘
		-- 创建并启动定时器
		spinner_timer = vim.uv.new_timer()
		spinner_timer:start(0, M.config.spinner_interval, function()
			vim.schedule(function()
				spinner_index = (spinner_index % #M.config.spinner_frames) + 1
				schedule_spinner_update()
			end)
		end)
	else
		if spinner_timer then
			spinner_timer:stop()
			spinner_timer:close()
			spinner_timer = nil
		end

		-- 停止后刷新一次状态栏，清除 spinner
		vim.api.nvim_exec_autocmds("User", { pattern = "LspStatusSpinner" })
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
-- 活动进度：["<client_id>:<token>"] = true
-- 必须带 client_id：不同 server 的 token 都从 1 开始，会互相覆盖。
-- token 也只能取 ev.data.params.token —— WorkDoneProgressBegin 里没有 token 字段，
-- 早期版本退化成用 title 当 key，同名任务会互相吞掉 begin/end。
local active_progress = {}

---清掉已退出 client 的残留 token（server 异常退出不会补发 end）
local function prune_dead_clients()
	for key in pairs(active_progress) do
		local client_id = tonumber(tostring(key):match("^(%d+):"))
		if client_id and not vim.lsp.get_client_by_id(client_id) then
			active_progress[key] = nil
		end
	end
end

vim.api.nvim_create_autocmd("LspProgress", {
	callback = function(ev)
		local data = ev.data or {}
		local val = data.params and data.params.value
		if not val or not data.client_id or not val.kind then
			return
		end

		local key = string.format("%d:%s", data.client_id, tostring(data.params.token))

		if val.kind == "begin" then
			active_progress[key] = true
		elseif val.kind == "end" then
			active_progress[key] = nil
		else
			return -- "report"：状态不变
		end

		prune_dead_clients()

		local running = false
		for _ in pairs(active_progress) do
			running = true
			break
		end
		spinner_set_active(running)
	end,
})

-- =========================================================
-- LSP 客户端显示函数
-- =========================================================
function M.lsp_clients()
	local ok, buf_clients = pcall(vim.lsp.get_clients, { bufnr = vim.api.nvim_get_current_buf() })

	if not ok or next(buf_clients) == nil then
		return "%#" .. M.config.highlight_group .. "# " .. "%*"
	end

	-- 客户端优先级配置
	local client_priority = {
		-- 默认：不在黑名单中的客户端最高优先级(101)
		-- 黑名单客户端可以设置0-100的优先级
		-- 0或负数：不显示为名字
		["ruff"] = 30,
		["ruff_lsp"] = 30,
		["eslint"] = 40,
		["rustowl"] = 30,
		["harper-ls"] = 50,
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
		-- 直接显示数字，超过99显示"99+"
		local client_count
		if total_clients > 99 then
			client_count = "99+"
		else
			client_count = tostring(total_clients)
		end

		local spin = spinner_icon()
		return string.format("%s%s", "%#" .. M.config.highlight_group .. "#" .. client_count .. "%*", spin)
	end

	-- 直接显示数字，超过99显示"99+"
	local client_count
	if total_clients > 99 then
		client_count = "99+"
	else
		client_count = tostring(total_clients)
	end

	-- 获取动态 spinner
	local spin = spinner_icon()

	return string.format(
		"%s.%s. %s",
		"%#" .. M.config.highlight_group .. "#" .. client_count .. "%*",
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
	active_progress = {}

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
