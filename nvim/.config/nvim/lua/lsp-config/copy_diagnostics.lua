-- lua/lsp-config/copy_diagnostics.lua
local M = {}

-- 从 settings.lua 导入图标配置
local settings = require("lsp-config.lsp_settings")

-- 获取图标（直接复用 settings 中的配置）
local function get_severity_icon(severity)
	if severity == vim.diagnostic.severity.ERROR then
		return settings.icons.ERROR
	elseif severity == vim.diagnostic.severity.WARN then
		return settings.icons.WARN
	elseif severity == vim.diagnostic.severity.INFO then
		return settings.icons.INFO
	elseif severity == vim.diagnostic.severity.HINT then
		return settings.icons.HINT
	end
	return "• "
end

-- 获取严重程度名称
local function get_severity_name(severity)
	return vim.diagnostic.severity[severity] or "UNKNOWN"
end

-- 格式化单个诊断消息（不带序号）
local function format_single_diagnostic(d)
	local severity_name = get_severity_name(d.severity)
	return string.format("[%s] %s [%s] - %s", severity_name, d.message, d.code or "No code", d.source or "?")
end

-- 格式化带序号的诊断消息（用于内部显示，但不复制序号）
local function format_diagnostic_preview(d, index)
	local icon = get_severity_icon(d.severity)
	local preview = d.message:len() > 50 and d.message:sub(1, 47) .. "..." or d.message
	return string.format("%s %s", icon, preview) -- 去掉序号
end

-- 按错误类型分组诊断信息
local function group_diagnostics_by_type(diagnostics)
	local groups = {}

	for _, d in ipairs(diagnostics) do
		local severity_name = get_severity_name(d.severity)
		local type_key = string.format("[%s] %s", severity_name, d.code or "No code")

		if not groups[type_key] then
			groups[type_key] = {
				severity = d.severity,
				code = d.code,
				severity_name = severity_name,
				messages = {},
				count = 0,
			}
		end

		local msg =
			string.format("%s [%s] - %s", d.message, d.source or "?", d.code and ("Code: " .. d.code) or "No code")

		table.insert(groups[type_key].messages, msg)
		groups[type_key].count = groups[type_key].count + 1
	end

	return groups
end

-- 格式化分组预览
local function format_group_preview(group)
	local icon = get_severity_icon(group.severity)
	return string.format(
		"%s %s (%d message%s)",
		icon,
		group.code and ("Code: " .. group.code) or "No code",
		group.count,
		group.count > 1 and "s" or ""
	)
end

-- 主函数：复制错误消息
function M.copy_error_message()
	-- 获取当前光标位置和缓冲区
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local bufnr = vim.api.nvim_get_current_buf()

	-- 获取当前行的诊断信息
	local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })

	if #diagnostics == 0 then
		vim.notify("No diagnostics found at current line", vim.log.levels.WARN)
		return
	end

	-- 按严重程度排序（错误优先）
	table.sort(diagnostics, function(a, b)
		return a.severity < b.severity
	end)

	-- 如果只有一个诊断，直接复制并返回
	if #diagnostics == 1 then
		local content = format_single_diagnostic(diagnostics[1])
		vim.fn.setreg("+", content)
		vim.fn.setreg('"', content)
		vim.notify("Copied diagnostic to clipboard", vim.log.levels.INFO)
		return
	end

	-- 构建选择菜单
	local choices = {}
	local choice_map = {}

	-- 先添加单个错误选项（按顺序，不带序号）
	for i, d in ipairs(diagnostics) do
		local display_name = format_diagnostic_preview(d, i) -- i 参数保留但未使用
		table.insert(choices, display_name)
		choice_map[#choices] = { type = "single", data = d }
	end

	-- 如果有多于1个诊断，添加分组选项和复制所有选项
	if #diagnostics > 1 then
		-- 按类型分组
		local groups = group_diagnostics_by_type(diagnostics)

		-- 添加分组选项（只有当某个类型有多个消息时才显示）
		for _, group in pairs(groups) do
			if group.count > 1 then
				local display_name = format_group_preview(group)
				table.insert(choices, display_name)
				choice_map[#choices] = { type = "group", data = group }
			end
		end

		-- 添加复制所有选项
		table.insert(choices, "📋 Copy all diagnostics")
		choice_map[#choices] = { type = "all", data = diagnostics }
	end

	-- 显示选择界面
	vim.ui.select(choices, {
		prompt = "Select diagnostics to copy:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		local selected = choice_map[idx]
		local content = ""

		if selected.type == "all" then
			-- 复制所有错误（不带序号）
			local lines = {}
			for i, d in ipairs(selected.data) do
				table.insert(lines, format_single_diagnostic(d))
			end
			content = table.concat(lines, "\n")
		elseif selected.type == "group" then
			-- 复制同类型的所有错误（不带序号）
			local group = selected.data
			local lines = {}
			table.insert(
				lines,
				string.format(
					"=== %s (%d messages) ===",
					group.code and ("Code: " .. group.code) or "No code",
					group.count
				)
			)

			for i, msg in ipairs(group.messages) do
				table.insert(lines, msg) -- 去掉序号
			end
			content = table.concat(lines, "\n")
		elseif selected.type == "single" then
			-- 复制单个错误（不带序号）
			content = format_single_diagnostic(selected.data)
		end

		-- 复制到寄存器
		if content and content ~= "" then
			vim.fn.setreg("+", content)
			vim.fn.setreg('"', content)
			vim.notify(string.format("Copied %d characters to clipboard", #content), vim.log.levels.INFO)
		end
	end)
end

return M
