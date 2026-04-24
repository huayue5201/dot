--- File: /Users/lijia/dotfile/nvim/.config/nvim/lua/dap-config/dap-extensions/breakpoint/column.lua
-- 重命名：inline.lua -> column.lua
local Base = require("dap-config.dap-extensions.breakpoint.base")

local M = setmetatable({}, { __index = Base })

function M:new(cfg)
	local o = Base.new(self, cfg)
	o.type = "column" -- 改名为 column
	o.config.line = cfg.line
	o.config.column = cfg.column -- 标准 column 字段
	o.config.condition = cfg.condition
	o.config.hitCondition = cfg.hitCondition
	o.config.bufnr = cfg.bufnr
	return o
end

return M
