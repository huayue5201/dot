local M = {}

--- 验证基础积木接口
--- @param mod table
--- @return boolean, string?  是否有效，错误信息
function M.validate_base_brick(mod)
	if not mod.name or type(mod.name) ~= "string" then
		return false, "基础积木必须包含字符串类型的 'name' 字段"
	end

	if mod.brick_type ~= "base" then
		return false, "基础积木的 brick_type 必须是 'base'"
	end

	if type(mod.resolve) ~= "function" then
		return false, "基础积木必须实现 'resolve' 函数"
	end

	return true
end

--- 验证框架积木接口
--- @param mod table
--- @return boolean, string? 是否有效，错误信息
function M.validate_frame_brick(mod)
	if not mod.name or type(mod.name) ~= "string" then
		return false, "框架积木必须包含字符串类型的 'name' 字段"
	end

	if mod.brick_type ~= "frame" then
		return false, "框架积木的 brick_type 必须是 'frame'"
	end

	if type(mod.execute) ~= "function" then
		return false, "框架积木必须实现 'execute' 函数"
	end

	return true
end

return M
