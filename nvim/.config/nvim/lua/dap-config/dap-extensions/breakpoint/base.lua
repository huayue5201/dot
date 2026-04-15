-- breakpoint/base.lua
local Event = require("dap-config.dap-extensions.event")

local Base = {}
Base.__index = Base

function Base:new(cfg)
	local o = setmetatable({}, self)
	o.id = cfg.id or tostring(os.time()) .. tostring(math.random(9999))
	o.config = cfg
	o.status = "pending"
	o.enabled = cfg.enabled ~= false -- 默认为 true，允许禁用

	-- 添加位置信息支持
	if cfg.bufnr and cfg.line then
		o.config.bufnr = cfg.bufnr
		o.config.line = cfg.line
		o.config.column = cfg.column -- 列号支持
	end

	return o
end

-- 设置断点位置
function Base:set_location(bufnr, line)
	self.config.bufnr = bufnr
	self.config.line = line
end

-- 设置启用/禁用状态
function Base:set_enabled(enabled)
	if self.enabled == enabled then
		return
	end
	self.enabled = enabled
	Event.emit("breakpoint_enabled_changed", self)
end

-- 切换启用/禁用状态
function Base:toggle_enabled()
	self:set_enabled(not self.enabled)
end

-- 检查断点是否启用
function Base:is_enabled()
	return self.enabled ~= false
end

return Base
