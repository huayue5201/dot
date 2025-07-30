-- lua/brickdag/bricks/env.lua
local uv = vim.loop

local EnvBrick = {
    name = "env",
    brick_type = "base",
    description = "环境变量解析与合并积木（自动注入exec_context）",
    version = "2.1.0",
}

--- 递归解析环境变量值
local function deep_resolve(value, context)
    if type(value) == "function" then
        return deep_resolve(value(context), context)
    elseif type(value) == "table" then
        local resolved = {}
        for k, v in pairs(value) do
            resolved[k] = deep_resolve(v, context)
        end
        return resolved
    end
    return tostring(value)
end

--- 解析环境变量配置
function EnvBrick.resolve(value, context)
    if type(value) == "function" then
        return value(context)
    end

    if type(value) ~= "table" then
        return {}
    end

    -- 支持特殊指令：禁用继承
    if value.__inherit == false then
        return deep_resolve(value, context) -- 完全自定义环境
    end

    -- 默认：解析并继承系统环境
    return deep_resolve(value, context)
end

--- 获取完整环境变量（系统环境 + 自定义环境）
function EnvBrick.get_full_env(custom_env, context)
    local parsed_env = EnvBrick.resolve(custom_env, context) or {}
    local system_env = uv.os_environ()

    -- 深度合并，自定义覆盖系统
    return vim.tbl_extend("force", system_env, parsed_env)
end

--- 在执行上下文中应用环境变量
--- @param exec_context table
function EnvBrick.apply(exec_context)
    exec_context.env = EnvBrick.get_full_env(exec_context.config and exec_context.config.env, exec_context)
    return exec_context.env
end

--- 添加环境变量转换器
function EnvBrick.add_transformer(name, transformer)
    EnvBrick.transformers = EnvBrick.transformers or {}
    EnvBrick.transformers[name] = transformer
end

return EnvBrick

