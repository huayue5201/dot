-- breakpoint/inline.lua
local Base = require("dap-config.dap-extensions.breakpoint.base")

local M = setmetatable({}, { __index = Base })

function M:new(cfg)
	local o = Base.new(self, cfg)
	o.type = "inline"
	o.config.line = cfg.line
	o.config.column = cfg.column
	o.config.condition = cfg.condition
	o.config.hitCondition = cfg.hitCondition
	o.config.bufnr = cfg.bufnr
	return o
end

return M
