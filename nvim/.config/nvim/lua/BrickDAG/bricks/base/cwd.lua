-- lua/BrickDAG/bricks/cwd.lua

local CwdBrick = {
	name = "cwd",
	brick_type = "base",
	description = "解析工作目录的基础积木",
}

--- 解析工作目录路径
--- @param value any 配置中的路径值
--- @param context table 执行上下文
--- @return string 解析后的工作目录路径
function CwdBrick.resolve(value, context)
	if type(value) == "function" then
		return value(context)
	elseif type(value) == "table" then
		-- 将数组拼接成路径
		return table.concat(value, "/")
	else
		return vim.fn.expand(tostring(value))
	end
end

return CwdBrick
