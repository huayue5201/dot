-- lua/brickdag/bricks/cmd.lua

local CmdBrick = {
	name = "cmd",
	brick_type = "base",
	description = "解析命令参数的基础积木",
}

--- 解析命令值
--- @param value any 配置中的命令值
--- @param context table 执行上下文
--- @return string 解析后的命令
function CmdBrick.resolve(value, context)
	if type(value) == "function" then
		return value(context)
	elseif type(value) == "table" then
		-- 将数组拼接成字符串（用空格分隔）
		return table.concat(value, " ")
	else
		return tostring(value)
	end
end

return CmdBrick
