-- lua/brickdag/bricks/base/vars.lua

local VarsBrick = {
    name = "vars",
    brick_type = "base",
    description = "字符串模板变量替换积木，支持 {var} 替换",
}

--- 替换字符串中所有 {var} 占位符为上下文中对应值
--- @param value string | table 需要替换的字符串或字符串数组
--- @param context table 上下文变量表，如 { file_path = "/path/to/file" }
--- @return string | table 替换后的字符串或字符串数组
local function replace_vars(value, context)
    local function replace_in_str(str)
        return (str:gsub("{(.-)}", function(key)
            local val = context[key]
            if val == nil then
                return "{" .. key .. "}" -- 找不到对应变量，保留原样
            end
            return tostring(val)
        end))
    end

    if type(value) == "string" then
        return replace_in_str(value)
    elseif type(value) == "table" then
        local result = {}
        for i, v in ipairs(value) do
            result[i] = replace_vars(v, context)
        end
        return result
    else
        return value
    end
end

function VarsBrick.resolve(value, context)
    -- 允许传函数
    if type(value) == "function" then
        value = value(context)
    end

    return replace_vars(value, context)
end

return VarsBrick
