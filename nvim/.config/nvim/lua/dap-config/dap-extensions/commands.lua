local manager = require("dap-config.dap-extensions.manager")
local popup = require("dap-config.dap-extensions.ui.popup")
local sign = require("dap-config.dap-extensions.ui.sign")

local M = {}

local FUNCTION_FIELDS = {
	{ label = "Function Name", key = "function_name" },
	{ label = "Condition (optional)", key = "condition" },
	{ label = "Hit Condition (optional)", key = "hit_condition" },
}

local DATA_FIELDS = {
	{ label = "Expression", key = "expression" },
	{ label = "Access Type (write/read/readWrite)", key = "access_type" },
	{ label = "Condition (optional)", key = "condition" },
	{ label = "Hit Condition (optional)", key = "hit_condition" },
}

-- 通过 LSP 获取函数定义位置（用于预显示待定断点）
local function get_function_location_from_lsp(function_name)
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(),
		position = vim.api.nvim_win_get_cursor(0),
	}

	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
		if client.server_capabilities.workspaceSymbolProvider then
			local result = client.request_sync("workspace/symbol", {
				query = function_name,
			}, 1000)
			if result and result.result then
				for _, symbol in ipairs(result.result) do
					if
						symbol.name == function_name
						and (
							symbol.kind == vim.lsp.protocol.SymbolKind.Function
							or symbol.kind == vim.lsp.protocol.SymbolKind.Method
						)
					then
						return {
							bufnr = vim.uri_to_bufnr(symbol.location.uri),
							line = symbol.location.range.start.line + 1,
						}
					end
				end
			end
		end
	end
	return nil
end

function M.add_function_breakpoint()
	popup.open({
		fields = FUNCTION_FIELDS,
		on_submit = function(result)
			if not result.function_name or result.function_name == "" then
				vim.notify("Function name required", "error")
				return
			end

			local opts = {}
			if result.condition and result.condition ~= "" then
				opts.condition = result.condition
			end
			if result.hit_condition and result.hit_condition ~= "" then
				opts.hitCondition = result.hit_condition
			end

			-- 尝试通过 LSP 获取函数位置（用于预显示）
			local location = get_function_location_from_lsp(result.function_name)
			if location then
				opts.bufnr = location.bufnr
				opts.line = location.line
				vim.notify(
					string.format("✓ Function breakpoint on '%s' at line %d", result.function_name, location.line),
					"info"
				)
			else
				-- 如果 LSP 找不到，使用光标位置作为临时位置
				local cursor = vim.api.nvim_win_get_cursor(0)
				opts.bufnr = vim.api.nvim_get_current_buf()
				opts.line = cursor[1]
				vim.notify(
					string.format(
						"⚠ Function breakpoint on '%s' (position pending, will update when hit)",
						result.function_name
					),
					"warn"
				)
			end

			local bp = manager.add_function_breakpoint(result.function_name, opts)

			-- 立即显示待定标志
			if bp.config.bufnr and bp.config.line then
				sign.show_sign(bp)
			end
		end,
	})
end

function M.add_data_breakpoint()
	popup.open({
		fields = DATA_FIELDS,
		on_submit = function(result)
			if not result.expression or result.expression == "" then
				vim.notify("Expression required", "error")
				return
			end

			local opts = {}
			if result.access_type and result.access_type ~= "" then
				opts.accessType = result.access_type
			end
			if result.condition and result.condition ~= "" then
				opts.condition = result.condition
			end
			if result.hit_condition and result.hit_condition ~= "" then
				opts.hitCondition = result.hit_condition
			end

			-- 数据断点使用光标位置
			local cursor = vim.api.nvim_win_get_cursor(0)
			opts.bufnr = vim.api.nvim_get_current_buf()
			opts.line = cursor[1]

			local bp = manager.add_data_breakpoint(result.expression, opts)

			-- 立即显示待定标志
			sign.show_sign(bp)

			vim.notify(string.format("✓ Data breakpoint on '%s'", result.expression), "info")
		end,
	})
end

function M.list_breakpoints()
	local bps = manager.list_breakpoints()
	if #bps == 0 then
		vim.notify("No breakpoints set", "info")
		return
	end

	local lines = { "=== DAP Extensions Breakpoints ===", "" }
	for _, bp in ipairs(bps) do
		local status_icon = ""
		if bp.status == "verified" then
			status_icon = "✓"
		elseif bp.status == "rejected" then
			status_icon = "✗"
		else
			status_icon = "○"
		end

		local line = string.format("%s [%s] %s", status_icon, bp.status:upper(), bp.type)

		if bp.type == "function" then
			line = line .. string.format(": %s", bp.config.function_name)
			if bp.config.bufnr and bp.config.line then
				line = line .. string.format(" at line %d", bp.config.line)
			end
			if bp.config.condition then
				line = line .. string.format("\n    └─ if: %s", bp.config.condition)
			end
			if bp.config.hitCondition then
				line = line .. string.format("\n    └─ hit: %s", bp.config.hitCondition)
			end
		elseif bp.type == "data" then
			line = line .. string.format(": %s", bp.config.expression)
			if bp.config.bufnr and bp.config.line then
				line = line .. string.format(" at line %d", bp.config.line)
			end
			if bp.config.accessType then
				line = line .. string.format(" (%s)", bp.config.accessType)
			end
			if bp.config.condition then
				line = line .. string.format("\n    └─ if: %s", bp.config.condition)
			end
		end

		table.insert(lines, line)
	end

	vim.notify(table.concat(lines, "\n"), "info", { title = "Breakpoints", timeout = 5000 })
end

function M.clear_breakpoints()
	local count = #manager.list_breakpoints()
	if count == 0 then
		vim.notify("No breakpoints to clear", "info")
		return
	end

	manager.clear_breakpoints()
	vim.notify(string.format("✓ Cleared %d breakpoint(s)", count), "info")
end

return M
