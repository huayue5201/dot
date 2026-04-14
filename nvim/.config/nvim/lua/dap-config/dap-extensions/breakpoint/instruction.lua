-- breakpoint/instruction.lua
local Base = require("dap-config.dap-extensions.breakpoint.base")

local M = setmetatable({}, { __index = Base })

function M:new(cfg)
	local o = Base.new(self, cfg)
	o.type = "instruction"
	o.instruction_reference = cfg.instruction_reference
	o.offset = cfg.offset or 0
	o.config.instruction_reference = cfg.instruction_reference
	o.config.offset = o.offset
	o.config.condition = cfg.condition
	o.config.hitCondition = cfg.hitCondition
	return o
end

return M
