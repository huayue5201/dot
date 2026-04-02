-- lua/lsp-config/copy_diagnostics.lua
local M = {}

local settings = require("lsp-config.lsp_settings")

---------------------------------------------------------
-- 图标与基础格式化
---------------------------------------------------------
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

local function get_severity_name(severity)
	return vim.diagnostic.severity[severity] or "UNKNOWN"
end

local function format_single_diagnostic(d)
	local severity_name = get_severity_name(d.severity)
	return string.format("[%s] %s [%s] - %s", severity_name, d.message, d.code or "No code", d.source or "?")
end

local function format_diagnostic_preview(d)
	local first_line = d.message:match("^[^\n]+") or d.message
	local preview = #first_line > 50 and first_line:sub(1, 47) .. "..." or first_line
	return string.format("%s %s", get_severity_icon(d.severity), preview)
end

---------------------------------------------------------
-- 辅助函数（先定义）
---------------------------------------------------------
-- 获取诊断位置的列信息
local function get_diagnostic_column(diagnostic)
	if diagnostic.range then
		return diagnostic.range.start.character
	end
	return diagnostic.col or 0
end

-- 获取错误行的完整代码
local function get_line_content(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)
	if lines and #lines > 0 then
		return lines[1]
	end
	return ""
end

-- 获取文件路径
local function get_file_path(bufnr)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath and filepath ~= "" then
		local cwd = vim.fn.getcwd()
		local relative = vim.fn.fnamemodify(filepath, ":.")
		if relative and relative ~= "" and not relative:match("^%.") then
			return relative
		end
		return filepath
	end
	return "[No file name]"
end

---------------------------------------------------------
-- AST 上下文提取（AI 友好版）
---------------------------------------------------------

local function get_node_text(node, bufnr)
	local ok, result = pcall(vim.treesitter.get_node_text, node, bufnr)
	if not ok or not result then
		return ""
	end
	return type(result) == "table" and table.concat(result, "\n") or result
end

-- 获取节点的行列范围
local function get_node_range(node)
	local start_row, start_col, end_row, end_col = node:range()
	return {
		start = { row = start_row, col = start_col },
		finish = { row = end_row, col = end_col },
	}
end

-- 获取包含指定位置的所有节点（按从外到内排序）
local function get_nodes_at_position(bufnr, lnum, col)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok then
		return {}
	end

	local tree = parser:parse()[1]
	if not tree then
		return {}
	end

	local root = tree:root()
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

		-- 先收集子节点
		for child in node:iter_children() do
			collect_nodes(child)
		end

		-- 然后添加当前节点
		table.insert(nodes, node)
	end

	collect_nodes(root)

	-- 按节点大小排序（最内层的在最后）
	table.sort(nodes, function(a, b)
		local a_start, a_end = a:range()
		local b_start, b_end = b:range()
		local a_size = (a_end - a_start) * 1000 + (a_end - a_start)
		local b_size = (b_end - b_start) * 1000 + (b_end - b_start)
		return a_size < b_size
	end)

	return nodes
end

-- 获取标识符节点（特别是导入的项）
local function get_identifier_node(bufnr, diagnostic)
	local lnum = diagnostic.lnum
	local col = get_diagnostic_column(diagnostic)

	local nodes = get_nodes_at_position(bufnr, lnum, col)

	-- 优先查找 identifier 相关的节点类型
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

	-- 如果没有找到标识符，返回最内层节点
	return #nodes > 0 and nodes[#nodes] or nil
end

-- 重要的节点类型
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

-- 向上查找有意义的父节点
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

-- 获取诊断位置的具体信息（AI 友好格式）
local function get_diagnostic_context(bufnr, diagnostic, error_node, context_node)
	local file_path = get_file_path(bufnr)
	local line_num = diagnostic.lnum + 1
	local line_content = get_line_content(bufnr, diagnostic.lnum)

	-- 获取错误节点的文本和类型
	local error_text = error_node and get_node_text(error_node, bufnr) or ""
	local error_type = error_node and error_node:type() or "unknown"

	-- 获取节点范围（用于定位）
	local node_range = error_node and get_node_range(error_node) or nil
	local start_col = node_range and node_range.start.col + 1 or 0
	local end_col = node_range and node_range.finish.col + 1 or 0

	-- 格式化输出
	local parts = {}

	-- 文件位置信息
	table.insert(parts, string.format("File: %s", file_path))
	table.insert(parts, string.format("Line: %d", line_num))
	table.insert(parts, string.format("Line content: %s", line_content))

	-- 错误位置的具体信息
	if start_col > 0 and end_col > 0 then
		table.insert(parts, string.format("Error position: columns %d-%d", start_col, end_col))
	end

	table.insert(parts, "")

	-- 错误节点（具体的错误位置）
	if error_text and error_text ~= "" then
		table.insert(parts, string.format("Error node [%s]:", error_type))
		table.insert(parts, error_text)
		table.insert(parts, "")
	end

	-- 上下文节点（包含错误的父节点）
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

-- 获取诊断位置的诊断节点
local function get_diagnostic_node_info(bufnr, diagnostic)
	-- 尝试获取标识符节点
	local error_node = get_identifier_node(bufnr, diagnostic)

	if not error_node then
		-- 降级方案：获取最内层节点
		local lnum = diagnostic.lnum
		local col = get_diagnostic_column(diagnostic)
		local nodes = get_nodes_at_position(bufnr, lnum, col)
		error_node = #nodes > 0 and nodes[#nodes] or nil
	end

	if not error_node then
		return nil, nil
	end

	local context_node = find_relevant_parent(error_node)
	return error_node, context_node
end

---------------------------------------------------------
-- AST 缓存
---------------------------------------------------------
local function create_ast_cache(bufnr)
	local cache = {}

	return function(diagnostic)
		local lnum = diagnostic.lnum
		local col = get_diagnostic_column(diagnostic)
		local cache_key = string.format("%d:%d", lnum, col)

		if cache[cache_key] then
			return cache[cache_key]
		end

		local error_node, context_node = get_diagnostic_node_info(bufnr, diagnostic)

		if not error_node then
			cache[cache_key] = "(No AST node found at this position)"
			return cache[cache_key]
		end

		local context = get_diagnostic_context(bufnr, diagnostic, error_node, context_node)
		cache[cache_key] = context

		return cache[cache_key]
	end
end

---------------------------------------------------------
-- 分组逻辑
---------------------------------------------------------
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

		local msg = string.format("%s [%s] - %s", d.message, d.source or "?", d.code or "No code")
		table.insert(groups[type_key].messages, msg)
		groups[type_key].count = groups[type_key].count + 1
	end

	return groups
end

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

---------------------------------------------------------
-- 主函数：复制诊断
---------------------------------------------------------
function M.copy_error_message()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1] - 1
	local bufnr = vim.api.nvim_get_current_buf()

	local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })

	if #diagnostics == 0 then
		vim.notify("No diagnostics found at current line", vim.log.levels.WARN)
		return
	end

	table.sort(diagnostics, function(a, b)
		return a.severity < b.severity
	end)

	local get_ast = create_ast_cache(bufnr)

	-- 单条诊断
	if #diagnostics == 1 then
		local d = diagnostics[1]
		local formatted = format_single_diagnostic(d)
		local content = string.format("%s\n\n%s", formatted, get_ast(d))

		vim.fn.setreg("+", content)
		vim.fn.setreg('"', content)
		vim.notify("Copied diagnostic with AST context", vim.log.levels.INFO)
		return
	end

	---------------------------------------------------------
	-- 多条诊断：构建选择菜单
	---------------------------------------------------------
	local choices = {}
	local choice_map = {}

	for _, d in ipairs(diagnostics) do
		local display_name = format_diagnostic_preview(d)
		table.insert(choices, display_name)
		choice_map[#choices] = { type = "single", data = d }
	end

	local groups = group_diagnostics_by_type(diagnostics)
	for _, group in pairs(groups) do
		if group.count > 1 then
			local display_name = format_group_preview(group)
			table.insert(choices, display_name)
			choice_map[#choices] = { type = "group", data = group }
		end
	end

	table.insert(choices, "📋 Copy all diagnostics")
	choice_map[#choices] = { type = "all", data = diagnostics }

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
			local lines = {}
			for _, d in ipairs(selected.data) do
				local formatted = format_single_diagnostic(d)
				table.insert(lines, formatted .. "\n\n" .. get_ast(d))
			end
			content = table.concat(lines, "\n\n====================\n\n")
		elseif selected.type == "group" then
			local group = selected.data
			local lines = {}

			table.insert(lines, string.format("=== %s (%d messages) ===", group.code or "No code", group.count))

			for _, d in ipairs(diagnostics) do
				if d.code == group.code then
					local formatted = format_single_diagnostic(d)
					table.insert(lines, formatted .. "\n\n" .. get_ast(d))
				end
			end

			content = table.concat(lines, "\n\n--------------------\n\n")
		elseif selected.type == "single" then
			local d = selected.data
			local formatted = format_single_diagnostic(d)
			content = formatted .. "\n\n" .. get_ast(d)
		end

		if content and content ~= "" then
			vim.fn.setreg("+", content)
			vim.fn.setreg('"', content)
			vim.notify("Copied diagnostic with AST context", vim.log.levels.INFO)
		end
	end)
end

return M
