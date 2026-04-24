-- dap-config/dap-extensions/commands.lua
local manager = require("dap-config.dap-extensions.manager")
local popup = require("dap-config.dap-extensions.ui.popup")
local sign = require("dap-config.dap-extensions.ui.sign")
local validator = require("dap-config.dap-extensions.validator")
local capabilities = require("dap-config.dap-capabilities")

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

-- ============================================================
-- 硬件断点命令
-- ============================================================

local HARDWARE_TYPES = {
	{ name = "Execute", access = "execute", desc = "在指定地址执行时中断", need_size = false },
	{ name = "Read", access = "read", desc = "读取指定地址时中断", need_size = true },
	{ name = "Write", access = "write", desc = "写入指定地址时中断", need_size = true },
	{ name = "Read/Write", access = "readWrite", desc = "读取或写入时中断", need_size = true },
}

local function get_hardware_fields(choice)
	local fields = {
		{ label = "Address (e.g., 0x401000)", key = "address" },
	}

	if choice.need_size then
		table.insert(fields, { label = "Size in bytes (default 1)", key = "size" })
	end

	table.insert(fields, { label = "Condition (optional)", key = "condition" })
	table.insert(fields, { label = "Hit Condition (optional)", key = "hit_condition" })

	return fields
end

local function address_to_expression(address)
	local clean_addr = address:gsub("^0x", "")
	return string.format("*0x%s", clean_addr)
end

local function get_function_location(function_name)
	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
		local caps = client.server_capabilities
		if caps and caps.workspaceSymbolProvider then
			local result = client.request_sync("workspace/symbol", {
				query = function_name,
			}, 1000)
			if result and result.result then
				for _, symbol in ipairs(result.result) do
					if symbol.name == function_name then
						local kind = symbol.kind
						if
							kind == vim.lsp.protocol.SymbolKind.Function
							or kind == vim.lsp.protocol.SymbolKind.Method
						then
							local location = symbol.location
							if location and location.uri and location.range then
								local bufnr = vim.uri_to_bufnr(location.uri)
								local line = location.range.start.line + 1
								return {
									bufnr = bufnr,
									line = line,
									source = "lsp",
								}
							end
						end
					end
				end
			end
		end
	end
	return nil
end

local function get_data_location()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return {
		bufnr = vim.api.nvim_get_current_buf(),
		line = cursor[1],
		source = "cursor",
	}
end

local function check_capability(cap_name, error_msg)
	if capabilities.supports then
		if not capabilities.supports(cap_name) then
			vim.notify(error_msg or "Current debug adapter does not support " .. cap_name, "error")
			return false
		end
		return true
	end
	return true
end

function M.add_function_breakpoint()
	if
		not check_capability(
			"supportsFunctionBreakpoints",
			"❌ Current debug adapter does not support function breakpoints"
		)
	then
		return
	end

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

			local location = get_function_location(result.function_name)
			if location then
				opts.bufnr = location.bufnr
				opts.line = location.line
				vim.notify(
					string.format(
						"✓ Function breakpoint on '%s' at line %d (LSP location)",
						result.function_name,
						location.line
					),
					"info"
				)
			else
				vim.notify(
					string.format("✓ Function breakpoint on '%s' (位置将在命中后更新)", result.function_name),
					"info"
				)
			end

			local bp = manager.add_function_breakpoint(result.function_name, opts)

			if bp.config.bufnr and bp.config.line then
				sign.show_sign(bp)
			end
		end,
	})
end

function M.add_data_breakpoint()
	if
		not check_capability("supportsDataBreakpoints", "❌ Current debug adapter does not support data breakpoints")
	then
		return
	end

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

			local location = get_data_location()
			opts.bufnr = location.bufnr
			opts.line = location.line

			local bp = manager.add_data_breakpoint(result.expression, opts)

			if bp then
				sign.show_sign(bp)
			end

			vim.notify(
				string.format("✓ Data breakpoint on '%s' at line %d", result.expression, location.line),
				"info"
			)
		end,
	})
end

function M.add_hardware_breakpoint()
	if
		not check_capability(
			"supportsInstructionBreakpoints",
			"❌ Current debug adapter does not support instruction breakpoints"
		)
	then
		return
	end

	vim.ui.select(HARDWARE_TYPES, {
		prompt = "🔧 选择硬件断点类型:",
		format_item = function(item)
			local access_icon = {
				execute = "⚡",
				read = "📖",
				write = "✍️",
				readWrite = "🔄",
			}
			local icon = access_icon[item.access] or "🔧"
			return string.format("%s  %-12s . %s", icon, item.name, item.desc)
		end,
	}, function(choice)
		if not choice then
			return
		end

		local fields = get_hardware_fields(choice)

		popup.open({
			fields = fields,
			on_submit = function(result)
				if not result.address or result.address == "" then
					vim.notify("❌ 地址不能为空！", "error")
					return
				end

				local opts = {}
				if result.condition and result.condition ~= "" then
					opts.condition = result.condition
				end
				if result.hit_condition and result.hit_condition ~= "" then
					opts.hitCondition = result.hit_condition
				end

				local bp = nil
				local size = tonumber(result.size) or 1

				if choice.access == "execute" then
					bp = manager.add_hardware_execute_breakpoint(result.address, opts)
					if bp then
						sign.show_sign(bp)
					end
				else
					if
						not check_capability(
							"supportsDataBreakpoints",
							"❌ Current debug adapter does not support data breakpoints"
						)
					then
						return
					end

					local location = get_data_location()
					local expr = address_to_expression(result.address)

					opts.accessType = choice.access
					opts.bufnr = location.bufnr
					opts.line = location.line
					opts.size = size

					if choice.access == "read" then
						bp = manager.add_hardware_read_breakpoint(expr, size, opts)
					elseif choice.access == "write" then
						bp = manager.add_hardware_write_breakpoint(expr, size, opts)
					elseif choice.access == "readWrite" then
						bp = manager.add_hardware_access_breakpoint(expr, size, opts)
					end

					if bp and bp.config.bufnr and bp.config.line then
						sign.show_sign(bp)
					end
				end

				if bp then
					local access_icon = {
						execute = "⚡",
						read = "📖",
						write = "✍️",
						readWrite = "🔄",
					}
					local icon = access_icon[choice.access] or "🔧"
					vim.notify(
						string.format("✓ 硬件断点: %s %s at %s", icon, choice.name, result.address),
						"info"
					)
				end
			end,
		})
	end)
end

function M.add_column_breakpoint()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current_line = cursor[1]
	local current_col = cursor[2] + 1
	local bufnr = vim.api.nvim_get_current_buf()

	local is_valid, reason = validator.is_valid_column_breakpoint_location(bufnr, current_line, current_col)
	if not is_valid then
		vim.notify(string.format("❌ Cannot set breakpoint: %s", reason or "Invalid location"), "error")
		return
	end

	local word = vim.fn.expand("<cword>")
	local hint = word ~= "" and string.format(" on '%s'", word) or ""

	popup.open({
		fields = {
			{ label = "Condition (optional)", key = "condition" },
			{ label = "Hit Condition (optional)", key = "hit_condition" },
		},
		on_submit = function(result)
			local opts = {}
			if result.condition and result.condition ~= "" then
				opts.condition = result.condition
			end
			if result.hit_condition and result.hit_condition ~= "" then
				opts.hitCondition = result.hit_condition
			end

			opts.bufnr = bufnr
			opts.line = current_line
			opts.column = current_col

			local bp = manager.add_column_breakpoint(current_line, current_col, opts)

			local col_msg = string.format("column %d", current_col)
			vim.notify(string.format("✓ Column breakpoint at line %d, %s%s", current_line, col_msg, hint), "info")

			local column_vt = require("dap-config.dap-extensions.ui.column_virtual_text")
			if column_vt and column_vt.show then
				column_vt.show(bp)
			end
		end,
	})
end

function M.quick_column_breakpoint()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = cursor[1]
	local col = cursor[2] + 1
	local bufnr = vim.api.nvim_get_current_buf()
	local word = vim.fn.expand("<cword>")
	local hint = word ~= "" and string.format(" on '%s'", word) or ""

	local is_valid, reason = validator.is_valid_column_breakpoint_location(bufnr, line, col)
	if not is_valid then
		vim.notify(string.format("❌ Cannot set breakpoint: %s", reason or "Invalid location"), "error")
		return
	end

	local existing = false
	local existing_bp = nil
	local breakpoints = manager.list_breakpoints()
	for _, bp in pairs(breakpoints) do
		if bp.type == "column" and bp.config.bufnr == bufnr and bp.config.line == line and bp.config.column == col then
			existing = true
			existing_bp = bp
			break
		end
	end

	if existing then
		vim.ui.input({
			prompt = "⚠️ Breakpoint exists. Replace? (y/n): ",
			default = "n",
		}, function(input)
			if input and input:lower() == "y" then
				if existing_bp and existing_bp.id then
					manager.remove_breakpoint(existing_bp.id)
				end
				local bp = manager.add_column_breakpoint(line, col, {})
				local column_vt = require("dap-config.dap-extensions.ui.column_virtual_text")
				if column_vt and column_vt.show then
					column_vt.show(bp)
				end
				vim.notify(
					string.format("✓ Column breakpoint replaced at line %d, column %d%s", line, col, hint),
					"info"
				)
			else
				vim.notify("Cancelled", "info")
			end
		end)
	else
		local bp = manager.add_column_breakpoint(line, col, {})
		local column_vt = require("dap-config.dap-extensions.ui.column_virtual_text")
		if column_vt and column_vt.show then
			column_vt.show(bp)
		end
		vim.notify(string.format("✓ Column breakpoint at line %d, column %d%s", line, col, hint), "info")
	end
end

function M.add_inline_breakpoint(...)
	vim.notify("add_inline_breakpoint is deprecated, use add_column_breakpoint", vim.log.levels.WARN)
	return M.add_column_breakpoint(...)
end

function M.quick_inline_breakpoint(...)
	vim.notify("quick_inline_breakpoint is deprecated, use quick_column_breakpoint", vim.log.levels.WARN)
	return M.quick_column_breakpoint(...)
end

function M.toggle_breakpoint_enabled()
	local bps = manager.list_breakpoints()
	if #bps == 0 then
		vim.notify("No breakpoints to toggle", "info")
		return
	end

	local items = {}
	for _, bp in ipairs(bps) do
		local status = bp.enabled ~= false and "✓" or "○"
		local label = ""
		if bp.type == "function" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.function_name)
		elseif bp.type == "data" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.expression)
		elseif bp.type == "instruction" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.instruction_reference)
		elseif bp.type == "column" then
			label = string.format("%s [%s] line %d", status, bp.type, bp.config.line)
		else
			label = string.format("%s [%s]", status, bp.type)
		end
		table.insert(items, { label = label, bp = bp })
	end

	vim.ui.select(items, {
		prompt = "🔘 breakpoint to toggle:",
		format_item = function(item)
			return item.label
		end,
		width = 60,
	}, function(choice)
		if choice and choice.bp then
			local new_state = choice.bp.enabled ~= false
			if choice.bp.set_enabled then
				choice.bp:set_enabled(not new_state)
			end
			sign.update_sign(choice.bp)
			vim.notify(string.format("%s breakpoint", not new_state and "Enabled" or "Disabled"), "info")
		end
	end)
end

-- 删除当前行的断点
function M.delete_breakpoint_at_current_line()
	local bufnr = vim.api.nvim_get_current_buf()
	local line = vim.api.nvim_win_get_cursor(0)[1]

	local bps = manager.list_breakpoints()
	for _, bp in ipairs(bps) do
		if bp.config.bufnr == bufnr and bp.config.line == line then
			manager.remove_breakpoint(bp.id)
			vim.notify(string.format("✓ Deleted %s breakpoint at line %d", bp.type, line), "info")
			return
		end
	end

	vim.notify(string.format("No breakpoint at line %d", line), "warn")
end

-- 选择删除断点
function M.toggle_breakpoint_deletion()
	local bps = manager.list_breakpoints()
	if #bps == 0 then
		vim.notify("No breakpoints to delete", "info")
		return
	end

	local items = {}
	for _, bp in ipairs(bps) do
		local status = bp.enabled ~= false and "✓" or "○"
		local label = ""
		if bp.type == "function" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.function_name)
		elseif bp.type == "data" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.expression)
		elseif bp.type == "instruction" then
			label = string.format("%s [%s] %s", status, bp.type, bp.config.instruction_reference)
		elseif bp.type == "column" then
			label = string.format("%s [%s] line %d", status, bp.type, bp.config.line)
		else
			label = string.format("%s [%s]", status, bp.type)
		end
		table.insert(items, { label = label, bp = bp })
	end

	vim.ui.select(items, {
		prompt = "🗑️ Select breakpoint to delete:",
		format_item = function(item)
			return item.label
		end,
		width = 60,
	}, function(choice)
		if choice and choice.bp then
			manager.remove_breakpoint(choice.bp.id)
			vim.notify(string.format("Deleted: %s", choice.label), "info")
		end
	end)
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

		local enabled_icon = bp.enabled ~= false and "" or " [disabled]"
		local line =
			string.format("%s [%s] %s%s", status_icon, string.upper(bp.status or "pending"), bp.type, enabled_icon)

		if bp.type == "function" then
			line = line .. string.format(": %s", bp.config.function_name)
			if bp.config.bufnr and bp.config.line then
				line = line .. string.format(" at line %d", bp.config.line)
			else
				line = line .. " (位置待定)"
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
		elseif bp.type == "instruction" then
			line = line .. string.format(": %s", bp.config.instruction_reference)
			if bp.config.offset and bp.config.offset ~= 0 then
				line = line .. string.format(" offset=%d", bp.config.offset)
			end
			if bp.config.condition then
				line = line .. string.format("\n    └─ if: %s", bp.config.condition)
			end
			if bp.config.hitCondition then
				line = line .. string.format("\n    └─ hit: %s", bp.config.hitCondition)
			end
		elseif bp.type == "column" then
			line = line .. string.format(": line %d", bp.config.line)
			if bp.config.column then
				line = line .. string.format(" column %d", bp.config.column)
			end
			if bp.config.condition then
				line = line .. string.format("\n    └─ if: %s", bp.config.condition)
			end
			if bp.config.hitCondition then
				line = line .. string.format("\n    └─ hit: %s", bp.config.hitCondition)
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
