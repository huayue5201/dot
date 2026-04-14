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

	-- 获取 manager 模块
	local manager = require("dap-config.dap-extensions.manager")

	-- 注册断点类型
	-- 函数断点：通过函数名设置，在函数入口处中断
	manager.register_type("function", require("dap-config.dap-extensions.breakpoint.function"))
	-- 数据断点：监控变量或内存地址的变化
	manager.register_type("data", require("dap-config.dap-extensions.breakpoint.data"))

	-- 获取 nvim-dap 模块
	local dap = require("dap")

	-- 监听调试会话启动事件
	-- 当调试器启动时，将 session 传递给 manager 进行初始化
	dap.listeners.after.event_initialized["dap_ext"] = function(session)
		manager.on_session(session)
	end

	-- 监听调试器停止事件（断点命中时触发）
	-- 当程序暂停时（断点命中、单步执行等），处理断点命中逻辑
	dap.listeners.after.event_stopped["dap_ext"] = function(session, event)
		manager.on_stopped(session, event)
	end

	-- 加载 UI 组件
	-- 断点标志：在代码行号旁显示断点图标（●、󰽷、 等）
	if opts.ui == nil or opts.ui.sign then
		require("dap-config.dap-extensions.ui.sign")
	end

	-- 虚拟文本：断点命中时在行尾显示详细信息
	if opts.ui == nil or opts.ui.virtual_text then
		require("dap-config.dap-extensions.ui.virtual_text")
	end

	-- 集成第三方插件
	-- 目前支持：dap-view（断点管理界面）
	if opts.integrations and opts.integrations.dap_view then
		local ok, integration = pcall(require, "dap-config.dap-extensions.integrations.dap-view")
		if ok then
			integration.setup()
		else
			vim.notify("dap-view integration failed: module not found", "warn")
		end
	end
end

-- ============================================================
-- 公共 API
-- ============================================================

--- 添加函数断点
--- @param function_name string 函数名
--- @param opts table 可选参数
--- @param opts.condition string 条件表达式，例如 "argc > 5"
--- @param opts.hitCondition string 命中次数条件，例如 "3"（第3次命中时触发）
--- @return table 断点对象
M.add_function_breakpoint = require("dap-config.dap-extensions.manager").add_function_breakpoint

--- 添加数据断点
--- @param expression string 表达式，例如 "global_var"、"*ptr"
--- @param opts table 可选参数
--- @param opts.accessType string 访问类型："write"（默认）、"read"、"readWrite"
--- @param opts.condition string 条件表达式
--- @param opts.hitCondition string 命中次数条件
--- @return table 断点对象
M.add_data_breakpoint = require("dap-config.dap-extensions.manager").add_data_breakpoint

--- 列出所有断点
--- @return table 断点列表，每个断点包含 id、type、status、config 字段
M.list_breakpoints = require("dap-config.dap-extensions.manager").list_breakpoints

--- 清除所有断点
M.clear_breakpoints = require("dap-config.dap-extensions.manager").clear_breakpoints

--- 命令模块（带 UI 交互）
--- 提供 add_function_breakpoint、add_data_breakpoint、list_breakpoints、clear_breakpoints 等命令
--- 使用方式：require("dap-config.dap-extensions").commands.add_function_breakpoint()
M.commands = require("dap-config.dap-extensions.commands")

return M
