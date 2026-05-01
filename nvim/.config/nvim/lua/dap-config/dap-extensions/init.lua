-- dap-config/dap-extensions/init.lua
local M = {}

function M.setup(opts)
	opts = opts or {}

	local manager = require("dap-config.dap-extensions.manager")

	manager.register_type("function", require("dap-config.dap-extensions.breakpoint.function"))
	manager.register_type("data", require("dap-config.dap-extensions.breakpoint.data"))
	manager.register_type("instruction", require("dap-config.dap-extensions.breakpoint.instruction"))
	manager.register_type("column", require("dap-config.dap-extensions.breakpoint.column"))
	manager.register_type("inline", require("dap-config.dap-extensions.breakpoint.column"))

	local dap = require("dap")

	dap.listeners.after.event_initialized["dap_ext"] = function(session)
		manager.on_session(session)
	end

	dap.listeners.after.event_stopped["dap_ext"] = function(session, event)
		manager.on_stopped(session, event)
	end

	if opts.ui == nil or opts.ui.sign then
		require("dap-config.dap-extensions.ui.sign")
	end

	if opts.ui == nil or opts.ui.virtual_text then
		require("dap-config.dap-extensions.ui.virtual_text")
	end
end

M.add_function_breakpoint = require("dap-config.dap-extensions.manager").add_function_breakpoint
M.add_data_breakpoint = require("dap-config.dap-extensions.manager").add_data_breakpoint
M.list_breakpoints = require("dap-config.dap-extensions.manager").list_breakpoints
M.clear_breakpoints = require("dap-config.dap-extensions.manager").clear_breakpoints
M.commands = require("dap-config.dap-extensions.commands")

M.add_column_breakpoint = require("dap-config.dap-extensions.manager").add_column_breakpoint

M.add_inline_breakpoint = function(...)
	vim.notify("add_inline_breakpoint is deprecated, use add_column_breakpoint", vim.log.levels.WARN)
	return require("dap-config.dap-extensions.manager").add_column_breakpoint(...)
end

M.add_hardware_execute_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_execute_breakpoint
M.add_hardware_read_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_read_breakpoint
M.add_hardware_write_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_write_breakpoint
M.add_hardware_access_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_access_breakpoint

-- 导出删除方法
M.delete_breakpoint_at_current_line = require("dap-config.dap-extensions.commands").delete_breakpoint_at_current_line
M.toggle_breakpoint_deletion = require("dap-config.dap-extensions.commands").toggle_breakpoint_deletion

return M
