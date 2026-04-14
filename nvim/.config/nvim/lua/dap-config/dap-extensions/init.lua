-- dap-config/dap-extensions/init.lua
-- DAP Extensions 主模块，提供函数断点、数据断点等扩展功能

local M = {}

--- 设置 DAP Extensions
--- @param opts table 配置选项
--- @param opts.ui table UI 配置
--- @param opts.ui.sign boolean 是否显示断点标志，默认 true
--- @param opts.ui.virtual_text boolean 是否显示虚拟文本，默认 true
--- @param opts.integrations table 第三方集成配置
--- @param opts.integrations.dap_view boolean 是否集成 dap-view，默认 false
function M.setup(opts)
	opts = opts or {}

	local manager = require("dap-config.dap-extensions.manager")

	-- 注册断点类型
	manager.register_type("function", require("dap-config.dap-extensions.breakpoint.function"))
	manager.register_type("data", require("dap-config.dap-extensions.breakpoint.data"))
	manager.register_type("instruction", require("dap-config.dap-extensions.breakpoint.instruction"))

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

	if opts.integrations and opts.integrations.dap_view then
		local ok, integration = pcall(require, "dap-config.dap-extensions.integrations.dap-view")
		if ok then
			integration.setup()
		else
			vim.notify("dap-view integration failed: module not found", "warn")
		end
	end
end

-- 公共 API
M.add_function_breakpoint = require("dap-config.dap-extensions.manager").add_function_breakpoint
M.add_data_breakpoint = require("dap-config.dap-extensions.manager").add_data_breakpoint
M.list_breakpoints = require("dap-config.dap-extensions.manager").list_breakpoints
M.clear_breakpoints = require("dap-config.dap-extensions.manager").clear_breakpoints
M.commands = require("dap-config.dap-extensions.commands")

-- 硬件断点 API
M.add_hardware_execute_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_execute_breakpoint
M.add_hardware_read_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_read_breakpoint
M.add_hardware_write_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_write_breakpoint
M.add_hardware_access_breakpoint = require("dap-config.dap-extensions.manager").add_hardware_access_breakpoint

return M
