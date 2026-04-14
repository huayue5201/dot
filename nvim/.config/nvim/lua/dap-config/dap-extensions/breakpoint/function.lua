-- breakpoint/function.lua
local Base = require("dap-config.dap-extensions.breakpoint.base")

local M = setmetatable({}, { __index = Base })

function M:new(cfg)
	local o = Base.new(self, cfg)
	o.type = "function"
	-- 将特定字段也放到 config 中统一管理
	o.config.function_name = cfg.function_name
	o.config.condition = cfg.condition
	o.config.hitCondition = cfg.hitCondition

	-- 为方便访问，也创建快捷方式（可选）
	o.function_name = cfg.function_name

	return o
end

return M
