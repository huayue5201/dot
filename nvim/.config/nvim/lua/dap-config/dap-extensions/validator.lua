-- dap-config/dap-extensions/validator.lua
local M = {}

local caps = require("dap-config.dap-capabilities")

---------------------------------------------------------------------
-- LSP 检查：判断位置是否处于可执行符号（函数/方法/构造函数）内部
---------------------------------------------------------------------
local function is_executable_position_by_lsp(bufnr, line, col)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	if not clients or #clients == 0 then
		return nil
	end

	for _, client in ipairs(clients) do
		if client.server_capabilities.documentSymbolProvider then
			local params = {
				textDocument = vim.lsp.util.make_text_document_params(bufnr),
			}

			local ok, result = pcall(function()
				return client.request_sync("textDocument/documentSymbol", params, 500)
			end)

			if not ok or not result or not result.result then
				goto continue
			end

			local symbols = result.result

			local function in_range(range)
				if not range then
					return false
				end
				local s = range.start
				local e = range["end"]
				return line >= s.line + 1 and line <= e.line + 1
			end

			local function check_symbol(sym)
				-- DocumentSymbol
				if sym.range then
					if in_range(sym.range) then
						local k = sym.kind
						if
							k == vim.lsp.protocol.SymbolKind.Function
							or k == vim.lsp.protocol.SymbolKind.Method
							or k == vim.lsp.protocol.SymbolKind.Constructor
						then
							return true
						end
					end
					if sym.children then
						for _, c in ipairs(sym.children) do
							if check_symbol(c) then
								return true
							end
						end
					end
				end

				-- SymbolInformation
				if sym.location and sym.location.range then
					if in_range(sym.location.range) then
						local k = sym.kind
						if
							k == vim.lsp.protocol.SymbolKind.Function
							or k == vim.lsp.protocol.SymbolKind.Method
							or k == vim.lsp.protocol.SymbolKind.Constructor
						then
							return true
						end
					end
				end

				return false
			end

			for _, sym in ipairs(symbols) do
				if check_symbol(sym) then
					return true
				end
			end
		end
		::continue::
	end

	return nil
end

---------------------------------------------------------------------
-- Tree-sitter 检查：判断是否处于可执行语句节点
---------------------------------------------------------------------
local function is_executable_position_by_treesitter(bufnr, line0, col0)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	local root = tree:root()
	if not root then
		return nil
	end

	local node = root:descendant_for_range(line0, col0, line0, col0)
	if not node then
		return false
	end

	-- 常见可执行节点类型（跨语言）
	local executable_types = {
		["function_definition"] = true,
		["function_declaration"] = true,
		["method_definition"] = true,
		["method_declaration"] = true,
		["call_expression"] = true,
		["assignment_expression"] = true,
		["update_expression"] = true,
		["binary_expression"] = true,
		["unary_expression"] = true,
		["return_statement"] = true,
		["expression_statement"] = true,
		["lexical_declaration"] = true,
		["variable_declaration"] = true,
		["local_declaration"] = true,
		["if_statement"] = true,
		["for_statement"] = true,
		["while_statement"] = true,
		["block"] = true,
	}

	-- 向上爬父节点
	while node do
		if executable_types[node:type()] then
			return true
		end
		node = node:parent()
	end

	return false
end

---------------------------------------------------------------------
-- 主入口：检查是否可设置内联断点
---------------------------------------------------------------------
function M.is_valid_inline_breakpoint_location(bufnr, line, col)
	-----------------------------------------------------------------
	-- ① 自动检测调试器是否支持 inline breakpoint
	-----------------------------------------------------------------
	local ok, reason = caps.supports_inline_breakpoints()
	if not ok then
		return false, reason
	end

	-----------------------------------------------------------------
	-- ② 基础检查
	-----------------------------------------------------------------
	local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
	if #lines == 0 then
		return false, "Line is empty"
	end

	local text = lines[1]
	if not text or text == "" then
		return false, "Line is empty"
	end

	if text:match("^%s*$") then
		return false, "Line contains only whitespace"
	end

	-- 注释行
	local comment_patterns = {
		"^%s*//",
		"^%s*#",
		"^%s*--",
		"^%s*/%*",
		"^%s*%*",
	}
	for _, p in ipairs(comment_patterns) do
		if text:match(p) then
			return false, "Cannot set breakpoint on comment line"
		end
	end

	if col > #text then
		return false, "Column exceeds line length"
	end

	local ch = text:sub(col, col)
	if ch == " " or ch == "\t" then
		return false, "Cursor is not on a code character"
	end

	-----------------------------------------------------------------
	-- ③ LSP 检查
	-----------------------------------------------------------------
	local lsp = is_executable_position_by_lsp(bufnr, line, col)
	if lsp ~= nil then
		if not lsp then
			return false, "Not executable (LSP)"
		end
		return true
	end

	-----------------------------------------------------------------
	-- ④ Tree-sitter 检查（0-based）
	-----------------------------------------------------------------
	local ts = is_executable_position_by_treesitter(bufnr, line - 1, col - 1)
	if ts ~= nil then
		if not ts then
			return false, "Not executable (Tree-sitter)"
		end
		return true
	end

	-----------------------------------------------------------------
	-- ⑤ 没有 LSP / TS → 基础检查通过即可
	-----------------------------------------------------------------
	return true
end

return M
