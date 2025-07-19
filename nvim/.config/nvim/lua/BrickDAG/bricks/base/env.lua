-- lua/brickdag/bricks/env.lua

local EnvBrick = {
	name = "env",
	brick_type = "base",
	description = "解析环境变量的基础积木",
}

--- 解析环境变量
--- @param value any 配置中的环境变量值
--- @param context table 执行上下文
--- @return table 解析后的环境变量表
function EnvBrick.resolve(value, context)
	if type(value) == "function" then
		return value(context)
	elseif type(value) == "table" then
		-- 递归解析表中的每个值
		local resolved = {}
		for k, v in pairs(value) do
			if type(v) == "function" then
				resolved[k] = v(context)
			else
				resolved[k] = tostring(v)
			end
		end
		return resolved
	else
		return {}
	end
end

return EnvBrick
