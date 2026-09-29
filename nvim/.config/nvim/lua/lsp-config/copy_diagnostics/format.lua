-- lua/lsp-config/copy_diagnostics/format.lua
---@brief 诊断复制：图标 / 严重级别 / 格式化 / 分组
local icons = require("lsp-config.icons")
local M = {}

function M.severity_icon(severity)
	if severity == vim.diagnostic.severity.ERROR then
		return icons.ERROR
	elseif severity == vim.diagnostic.severity.WARN then
		return icons.WARN
	elseif severity == vim.diagnostic.severity.INFO then
		return icons.INFO
	elseif severity == vim.diagnostic.severity.HINT then
		return icons.HINT
	end
	return "• "
end

function M.severity_name(severity)
	return vim.diagnostic.severity[severity] or "UNKNOWN"
end

---单条诊断的完整文本
function M.single(d)
	return string.format("[%s] %s [%s] - %s", M.severity_name(d.severity), d.message, d.code or "No code", d.source or "?")
end

---单条诊断的一行预览
function M.preview(d)
	local first_line = d.message:match("^[^\n]+") or d.message
	local preview = #first_line > 50 and first_line:sub(1, 47) .. "..." or first_line
	return string.format("%s %s", M.severity_icon(d.severity), preview)
end

---诊断位置的列信息
function M.column(diagnostic)
	if diagnostic.range then
		return diagnostic.range.start.character
	end
	return diagnostic.col or 0
end

---错误行的完整内容
function M.line_content(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
	if lines and #lines > 0 then
		return lines[1]
	end
	return ""
end

---文件路径（尽量相对 cwd）
function M.file_path(bufnr)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath and filepath ~= "" then
		local relative = vim.fn.fnamemodify(filepath, ":.")
		if relative and relative ~= "" and not relative:match("^%.") then
			return relative
		end
		return filepath
	end
	return "[No file name]"
end

---按「严重级别 + code」分组
function M.group_by_type(diagnostics)
	local groups = {}

	for _, d in ipairs(diagnostics) do
		local severity_name = M.severity_name(d.severity)
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

		local msg = string.format("%s [%s] - %s", d.message, d.source or "?", d.code or "No code")
		table.insert(groups[type_key].messages, msg)
		groups[type_key].count = groups[type_key].count + 1
	end

	return groups
end

---分组的一行预览
function M.group_preview(group)
	local icon = M.severity_icon(group.severity)
	return string.format(
		"%s %s (%d message%s)",
		icon,
		group.code and ("Code: " .. group.code) or "No code",
		group.count,
		group.count > 1 and "s" or ""
	)
end

return M
