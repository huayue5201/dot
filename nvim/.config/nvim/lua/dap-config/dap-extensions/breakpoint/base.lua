-- breakpoint/base.lua
local Base = {}
Base.__index = Base

function Base:new(cfg)
	local o = setmetatable({}, self)
	o.id = cfg.id or tostring(os.time()) .. tostring(math.random(9999))
	o.config = cfg
	o.status = "pending"

	-- 添加位置信息支持
	if cfg.bufnr and cfg.line then
		o.config.bufnr = cfg.bufnr
		o.config.line = cfg.line
		o.config.column = cfg.column -- 新增列号支持
	end

	return o
end

-- 设置断点位置
function Base:set_location(bufnr, line)
	self.config.bufnr = bufnr
	self.config.line = line
end

return Base
