-- core/interface.lua
local M = {}

--- @class BaseBrick
--- @field name string 积木名称
--- @field brick_type "base" 积木类型
--- @field resolve fun(value: any, context: table): any 参数解析方法

--- @class FrameBrick
--- @field name string 框架名称
--- @field brick_type "frame" 框架类型
--- @field execute fun(exec_context: table): boolean, string 执行方法

--- 验证基础积木接口
--- @param brick table
--- @return boolean valid, string? error
function M.validate_base_brick(brick)
	if type(brick.name) ~= "string" then
		return false, "Base brick must have a string 'name' field"
	end

	if brick.brick_type ~= "base" then
		return false, "Base brick must have brick_type = 'base'"
	end

	if type(brick.resolve) ~= "function" then
		return false, "Base brick must implement 'resolve' function"
	end

	return true
end

--- 验证框架积木接口
--- @param frame table
--- @return boolean valid, string? error
function M.validate_frame_brick(frame)
	if type(frame.name) ~= "string" then
		return false, "Frame brick must have a string 'name' field"
	end

	if frame.brick_type ~= "frame" then
		return false, "Frame brick must have brick_type = 'frame'"
	end

	if type(frame.execute) ~= "function" then
		return false, "Frame brick must implement 'execute' function"
	end

	return true
end

return M
