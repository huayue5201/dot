-- core/value_resolver.lua
local M = {}

--- 解析单个值（支持函数和变量替换）
--- @param value any
--- @param context table
--- @return any
function M.resolve_value(value, context)
    if type(value) == "function" then
        return value(context)
    elseif type(value) == "string" then
        return value:gsub("%${([%w_]+)}", function(var)
            return context[var] or ("${" .. var .. "}")
        end)
    end
    return value
end

--- 解析整个参数表
--- @param params table
--- @param context table
--- @return table
function M.resolve_parameters(params, context)
    local resolved = {}
    for key, value in pairs(params) do
        resolved[key] = M.resolve_value(value, context)
    end
    return resolved
end

return M

