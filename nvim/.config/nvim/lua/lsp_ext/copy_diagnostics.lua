-- lua/lsp_ext/copy_diagnostics.lua
---@brief 复制当前行诊断：附带 Treesitter AST 上下文（AI 友好格式）
local icons = require("lsp_ext.icons")

local M = {}

---------------------------------------------------------
-- 诊断文本格式化
---------------------------------------------------------

local function severity_icon(severity)
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

local function severity_name(severity)
	return vim.diagnostic.severity[severity] or "UNKNOWN"
end

---单条诊断的完整文本
local function single(d)
	return string.format(
		"[%s] %s [%s] - %s",
		severity_name(d.severity),
		d.message,
		d.code or "No code",
		d.source or "?"
	)
end

---单条诊断的一行预览
local function preview(d)
	local first_line = d.message:match("^[^\n]+") or d.message
	local text = #first_line > 50 and first_line:sub(1, 47) .. "..." or first_line
	return string.format("%s %s", severity_icon(d.severity), text)
end

---诊断位置的列
local function column(diagnostic)
	if diagnostic.range then
		return diagnostic.range.start.character
	end
	return diagnostic.col or 0
end

---错误行的完整内容
local function line_content(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
	return lines and lines[1] or ""
end

---文件路径（尽量相对 cwd）
local function file_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path and path ~= "" then
		local relative = vim.fn.fnamemodify(path, ".")
		if relative and relative ~= "" and not relative:match("^%.") then
			return relative
		end
		return path
	end
	return "[No file name]"
end

---按「严重级别 + code」分组
local function group_by_type(diagnostics)
	local groups = {}
	for _, d in ipairs(diagnostics) do
		local key = string.format("[%s] %s", severity_name(d.severity), d.code or "No code")
		local group = groups[key]
		if not group then
			group = { severity = d.severity, code = d.code, count = 0 }
			groups[key] = group
		end
		group.count = group.count + 1
	end
	return groups
end

---分组的一行预览
local function group_preview(group)
	return string.format(
		"%s %s (%d message%s)",
		severity_icon(group.severity),
		group.code and ("Code: " .. group.code) or "No code",
		group.count,
		group.count > 1 and "s" or ""
	)
end

---------------------------------------------------------
-- Treesitter AST 上下文
---------------------------------------------------------

local IMPORTANT_NODE_TYPES = {
	"function_definition",
	"method_definition",
	"function_declaration",
	"class_declaration",
	"class_definition",
	"struct_item",
	"impl_item",
	"interface_declaration",
	"if_statement",
	"for_statement",
	"while_statement",
	"match_expression",
	"try_statement",
	"catch_clause",
	"call_expression",
	"assignment_expression",
	"binary_expression",
	"let_declaration",
	"variable_declaration",
	"const_declaration",
	"block",
	"compound_statement",
	"use_list",
	"use_declaration",
	"mod_item",
	"field_declaration",
	"parameter",
	"scoped_identifier",
	"import_statement",
	"import_specifier",
}

local IDENTIFIER_TYPES = {
	"identifier",
	"field_identifier",
	"scoped_identifier",
	"type_identifier",
}

local function get_node_text(node, bufnr)
	local ok, result = pcall(vim.treesitter.get_node_text, node, bufnr)
	if not ok or not result then
		return ""
	end
	return type(result) == "table" and table.concat(result, "\n") or result
end

---包含指定位置的所有节点（从外到内）
local function get_nodes_at_position(bufnr, lnum, col)
	local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
	if not lang then
		return {}
	end
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang, { error = false })
	if not ok or not parser then
		return {}
	end
	local trees = parser:parse()
	local root = trees and trees[1] and trees[1]:root()
	if not root then
		return {}
	end

	local nodes = {}
	local function collect(node)
		local start_row, start_col, end_row, end_col = node:range()
		if lnum < start_row or lnum > end_row then
			return
		end
		if lnum == start_row and col < start_col then
			return
		end
		if lnum == end_row and col > end_col then
			return
		end
		for child in node:iter_children() do
			collect(child)
		end
		table.insert(nodes, node)
	end
	collect(root)

	table.sort(nodes, function(a, b)
		local a_start, a_end = a:range()
		local b_start, b_end = b:range()
		return (a_end - a_start) < (b_end - b_start)
	end)

	return nodes
end

---标识符节点（优先），否则取最内层节点
local function get_identifier_node(bufnr, diagnostic, nodes)
	for i = #nodes, 1, -1 do
		local node_type = nodes[i]:type()
		for _, id_type in ipairs(IDENTIFIER_TYPES) do
			if node_type == id_type then
				return nodes[i]
			end
		end
	end
	return #nodes > 0 and nodes[#nodes] or nil
end

local function is_important(node)
	local t = node:type()
	for _, v in ipairs(IMPORTANT_NODE_TYPES) do
		if t == v then
			return true
		end
	end
	return false
end

---向上查找有意义的父节点
local function find_relevant_parent(node)
	local current, depth = node, 0
	while current and depth < 10 do
		if is_important(current) then
			return current
		end
		current = current:parent()
		depth = depth + 1
	end
	return node:parent() or node
end

---诊断位置的 AST 上下文（AI 友好格式）
local function ast_context(bufnr, diagnostic)
	local lnum = diagnostic.lnum
	local nodes = get_nodes_at_position(bufnr, lnum, column(diagnostic))

	local error_node = get_identifier_node(bufnr, diagnostic, nodes)
	if not error_node then
		return "(No AST node found at this position)"
	end
	local context_node = find_relevant_parent(error_node)

	local error_text = get_node_text(error_node, bufnr)
	local start_row, start_col, _, end_col = error_node:range()

	local parts = {
		string.format("File: %s", file_path(bufnr)),
		string.format("Line: %d", lnum + 1),
		string.format("Line content: %s", line_content(bufnr, lnum)),
	}
	if start_row >= 0 and end_col > start_col then
		table.insert(parts, string.format("Error position: columns %d-%d", start_col + 1, end_col + 1))
	end
	table.insert(parts, "")

	if error_text ~= "" then
		table.insert(parts, string.format("Error node [%s]:", error_node:type()))
		table.insert(parts, error_text)
		table.insert(parts, "")
	end

	if context_node then
		local context_text = get_node_text(context_node, bufnr)
		if context_text ~= "" and context_text ~= error_text then
			table.insert(parts, string.format("Context node [%s]:", context_node:type()))
			table.insert(parts, context_text)
			table.insert(parts, "")
		end
	end

	return table.concat(parts, "\n")
end

---带缓存的 AST 上下文获取函数（同一位置只解析一次）
---@param bufnr integer
---@return fun(diagnostic: table): string
local function create_ast_cache(bufnr)
	local cache = {}
	return function(diagnostic)
		local key = string.format("%d:%d", diagnostic.lnum, column(diagnostic))
		if not cache[key] then
			cache[key] = ast_context(bufnr, diagnostic)
		end
		return cache[key]
	end
end

---------------------------------------------------------
-- 入口
---------------------------------------------------------

local function copy_to_registers(content)
	vim.fn.setreg("+", content)
	vim.fn.setreg('"', content)
	vim.notify("Copied diagnostic with AST context", vim.log.levels.INFO)
end

---复制光标所在行的诊断（多条时弹选择菜单）
function M.copy_error_message()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })
	if #diagnostics == 0 then
		vim.notify("No diagnostics found at current line", vim.log.levels.WARN)
		return
	end
	table.sort(diagnostics, function(a, b)
		return a.severity < b.severity
	end)

	local get_ast = create_ast_cache(bufnr)

	if #diagnostics == 1 then
		copy_to_registers(single(diagnostics[1]) .. "\n\n" .. get_ast(diagnostics[1]))
		return
	end

	-- 多条诊断：单条 / 同 code 分组 / 全部
	local choices, choice_map = {}, {}
	for _, d in ipairs(diagnostics) do
		table.insert(choices, preview(d))
		choice_map[#choices] = { type = "single", data = d }
	end
	for _, group in pairs(group_by_type(diagnostics)) do
		if group.count > 1 then
			table.insert(choices, group_preview(group))
			choice_map[#choices] = { type = "group", data = group }
		end
	end
	table.insert(choices, "📋 Copy all diagnostics")
	choice_map[#choices] = { type = "all" }

	vim.ui.select(choices, { prompt = "Select diagnostics to copy:" }, function(_, idx)
		local selected = idx and choice_map[idx]
		if not selected then
			return
		end

		local content
		if selected.type == "all" then
			local parts = {}
			for _, d in ipairs(diagnostics) do
				table.insert(parts, single(d) .. "\n\n" .. get_ast(d))
			end
			content = table.concat(parts, "\n\n====================\n\n")
		elseif selected.type == "group" then
			local group = selected.data
			local parts = { string.format("=== %s (%d messages) ===", group.code or "No code", group.count) }
			for _, d in ipairs(diagnostics) do
				if d.code == group.code then
					table.insert(parts, single(d) .. "\n\n" .. get_ast(d))
				end
			end
			content = table.concat(parts, "\n\n--------------------\n\n")
		else
			local d = selected.data
			content = single(d) .. "\n\n" .. get_ast(d)
		end

		if content and content ~= "" then
			copy_to_registers(content)
		end
	end)
end

return M
