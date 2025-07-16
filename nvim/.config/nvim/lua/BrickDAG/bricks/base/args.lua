-- lua/BrickDAG/bricks/args.lua
local ArgsBrick = {
	name = "args",
	brick_type = "base",
	description = "解析命令行参数的基础积木",
}

-- 递归解析函数，确保所有值都转换为字符串
local function deep_resolve(value, context)
	if type(value) == "function" then
		return deep_resolve(value(context), context)
	elseif type(value) == "table" then
		local resolved = {}
		for _, v in ipairs(value) do
			local result = deep_resolve(v, context)
			if type(result) == "table" then
				for _, item in ipairs(result) do
					table.insert(resolved, tostring(item))
				end
			else
				table.insert(resolved, tostring(result))
			end
		end
		return resolved
	else
		return tostring(value)
	end
end

function ArgsBrick.resolve(value, context)
	-- 处理函数返回值
	if type(value) == "function" then
		value = value(context)
	end

	-- 处理字符串
	if type(value) == "string" then
		return vim.split(value, "%s+")
	end

	-- 处理数组
	if type(value) == "table" then
		return deep_resolve(value, context)
	end

	-- 其他类型转换为数组
	return { tostring(value) }
end

return ArgsBrick
