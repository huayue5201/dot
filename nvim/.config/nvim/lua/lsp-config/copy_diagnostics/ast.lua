-- lua/lsp-config/copy_diagnostics/ast.lua
---@brief 诊断复制：Treesitter AST 上下文提取
local format = require("lsp-config.copy_diagnostics.format")
local M = {}

local function get_node_text(node, bufnr)
	local ok, result = pcall(vim.treesitter.get_node_text, node, bufnr)
	if not ok or not result then
		return ""
	end
	return type(result) == "table" and table.concat(result, "\n") or result
end

---获取节点的行列范围
local function get_node_range(node)
	local start_row, start_col, end_row, end_col = node:range()
	return {
		start = { row = start_row, col = start_col },
		finish = { row = end_row, col = end_col },
	}
end

---获取包含指定位置的所有节点（按从外到内排序）
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
	if not trees or not trees[1] then
		return {}
	end

	local root = trees[1]:root()
	if not root then
		return {}
	end

	local nodes = {}

	local function collect_nodes(node)
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
			collect_nodes(child)
		end

		table.insert(nodes, node)
	end

	collect_nodes(root)

	table.sort(nodes, function(a, b)
		local a_start, a_end = a:range()
		local b_start, b_end = b:range()
		local a_size = (a_end - a_start) * 1000 + (a_end - a_start)
		local b_size = (b_end - b_start) * 1000 + (b_end - b_start)
		return a_size < b_size
	end)

	return nodes
end

---获取标识符节点（特别是导入的项）
local function get_identifier_node(bufnr, diagnostic)
	local lnum = diagnostic.lnum
	local col = format.column(diagnostic)

	local nodes = get_nodes_at_position(bufnr, lnum, col)

	local identifier_types = {
		"identifier",
		"field_identifier",
		"scoped_identifier",
		"type_identifier",
	}

	-- 从最内层向外查找
	for i = #nodes, 1, -1 do
		local node = nodes[i]
		local node_type = node:type()
		for _, id_type in ipairs(identifier_types) do
			if node_type == id_type then
				return node
			end
		end
	end

	return #nodes > 0 and nodes[#nodes] or nil
end

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

local function is_important(node)
	if not node then
		return false
	end
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
	if not node then
		return nil
	end

	local current = node
	local max_depth = 10
	local depth = 0

	while current and depth < max_depth do
		if is_important(current) then
			return current
		end
		current = current:parent()
		depth = depth + 1
	end

	return node:parent() or node
end

---获取诊断位置的具体信息（AI 友好格式）
local function get_diagnostic_context(bufnr, diagnostic, error_node, context_node)
	local file_path = format.file_path(bufnr)
	local line_num = diagnostic.lnum + 1
	local line_content = format.line_content(bufnr, diagnostic.lnum)

	local error_text = error_node and get_node_text(error_node, bufnr) or ""
	local error_type = error_node and error_node:type() or "unknown"

	local node_range = error_node and get_node_range(error_node) or nil
	local start_col = node_range and node_range.start.col + 1 or 0
	local end_col = node_range and node_range.finish.col + 1 or 0

	local parts = {}

	table.insert(parts, string.format("File: %s", file_path))
	table.insert(parts, string.format("Line: %d", line_num))
	table.insert(parts, string.format("Line content: %s", line_content))

	if start_col > 0 and end_col > 0 then
		table.insert(parts, string.format("Error position: columns %d-%d", start_col, end_col))
	end

	table.insert(parts, "")

	if error_text and error_text ~= "" then
		table.insert(parts, string.format("Error node [%s]:", error_type))
		table.insert(parts, error_text)
		table.insert(parts, "")
	end

	if context_node then
		local context_text = get_node_text(context_node, bufnr)
		local context_type = context_node:type()
		if context_text and context_text ~= "" and context_text ~= error_text then
			table.insert(parts, string.format("Context node [%s]:", context_type))
			table.insert(parts, context_text)
			table.insert(parts, "")
		end
	end

	return table.concat(parts, "\n")
end

---获取诊断位置的诊断节点
local function get_diagnostic_node_info(bufnr, diagnostic)
	local error_node = get_identifier_node(bufnr, diagnostic)

	if not error_node then
		local lnum = diagnostic.lnum
		local col = format.column(diagnostic)
		local nodes = get_nodes_at_position(bufnr, lnum, col)
		error_node = #nodes > 0 and nodes[#nodes] or nil
	end

	if not error_node then
		return nil, nil
	end

	local context_node = find_relevant_parent(error_node)
	return error_node, context_node
end

---创建一个带缓存的 AST 上下文获取函数
---@param bufnr integer
---@return fun(diagnostic: table): string
function M.create_cache(bufnr)
	local cache = {}

	return function(diagnostic)
		local lnum = diagnostic.lnum
		local col = format.column(diagnostic)
		local cache_key = string.format("%d:%d", lnum, col)

		if cache[cache_key] then
			return cache[cache_key]
		end

		local error_node, context_node = get_diagnostic_node_info(bufnr, diagnostic)

		if not error_node then
			cache[cache_key] = "(No AST node found at this position)"
			return cache[cache_key]
		end

		cache[cache_key] = get_diagnostic_context(bufnr, diagnostic, error_node, context_node)
		return cache[cache_key]
	end
end

return M
