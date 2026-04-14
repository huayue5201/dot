local manager = require("dap-config.dap-extensions.manager")
local popup = require("dap-config.dap-extensions.ui.popup")
local sign = require("dap-config.dap-extensions.ui.sign")
local breakpoint_state = require("dap-config.breakpoint_state")

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

-- 根据类型动态生成输入字段
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

-- ============================================================
-- 位置获取策略
-- ============================================================

-- 1. 函数断点位置：优先 LSP，显示待定标志，命中后更新
local function get_function_location(function_name)
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
							source = "lsp",
						}
					end
				end
			end
		end
	end
	return nil
end

-- 2. 数据断点位置：使用当前光标位置（用户知道变量在哪）
local function get_data_location()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return {
		bufnr = vim.api.nvim_get_current_buf(),
		line = cursor[1],
		source = "cursor",
	}
end

-- 保存断点并同步
local function save_and_sync()
	vim.defer_fn(function()
		breakpoint_state.sync_ext_breakpoints()
	end, 100)
end

-- ============================================================
-- 函数断点
-- ============================================================

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

			save_and_sync()
		end,
	})
end

-- ============================================================
-- 数据断点
-- ============================================================

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

			local location = get_data_location()
			opts.bufnr = location.bufnr
			opts.line = location.line

			local bp = manager.add_data_breakpoint(result.expression, opts)

			sign.show_sign(bp)

			vim.notify(
				string.format("✓ Data breakpoint on '%s' at line %d", result.expression, location.line),
				"info"
			)

			save_and_sync()
		end,
	})
end

-- ============================================================
-- 硬件断点
-- ============================================================

function M.add_hardware_breakpoint()
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

				local size = tonumber(result.size) or 1
				local bp = nil

				if choice.access == "execute" then
					bp = manager.add_hardware_execute_breakpoint(result.address, opts)
				elseif choice.access == "read" then
					bp = manager.add_hardware_read_breakpoint(result.address, size, opts)
				elseif choice.access == "write" then
					bp = manager.add_hardware_write_breakpoint(result.address, size, opts)
				elseif choice.access == "readWrite" then
					bp = manager.add_hardware_access_breakpoint(result.address, size, opts)
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
					save_and_sync()
				end
			end,
		})
	end)
end

-- ============================================================
-- 列表和清除
-- ============================================================

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
			if bp.config.accessType then
				line = line .. string.format(" (%s)", bp.config.accessType)
			end
			if bp.config.size and bp.config.size > 1 then
				line = line .. string.format(" size=%d", bp.config.size)
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
	save_and_sync()
end

return M
