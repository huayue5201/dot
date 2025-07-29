local M = {}

--- 验证基础积木接口
--- @param mod table
--- @return boolean, string?
function M.validate_base_brick(mod)
    if not mod.name or type(mod.name) ~= "string" then
        return false, "基础积木必须包含字符串类型的 'name' 字段"
    end

    if mod.brick_type ~= "base" then
        return false, ("基础积木 [%s] 的 brick_type 必须是 'base'"):format(mod.name)
    end

    if type(mod.resolve) ~= "function" then
        return false, ("基础积木 [%s] 必须实现 'resolve' 函数"):format(mod.name)
    end

    return true
end

--- 验证框架积木接口 (新增完整验证逻辑)
--- @param mod table
--- @return boolean, string?
function M.validate_frame_brick(mod)
    if not mod.name or type(mod.name) ~= "string" then
        return false, "框架积木必须包含字符串类型的 'name' 字段"
    end

    if mod.brick_type ~= "frame" then
        return false, ("框架积木 [%s] 的 brick_type 必须是 'frame'"):format(mod.name)
    end

    if type(mod.execute) ~= "function" then
        return false, ("框架积木 [%s] 必须实现 'execute' 函数"):format(mod.name)
    end

    -- 新增：检查是否有描述字段
    if not mod.description or type(mod.description) ~= "string" then
        return false, ("框架积木 [%s] 必须包含 'description' 字段"):format(mod.name)
    end

    return true
end

return M

