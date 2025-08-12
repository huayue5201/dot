-- lua/brickdag/ui/views/icon_manager.lua
local BricksRegistry = require("brickdag.core.bricks_registry")

local icon_map = {
    base = "󱓐 ",
    frame = " ",
    -- root= " ",
    config_option = "󱚠 ",
    dependency = "←",
    description = " ",
}

local user_icons = {}

local M = {}

-- 注册用户自定义图标
function M.register_icon(name, icon)
    user_icons[name] = icon
end

-- 获取图标（包含特殊类型和积木类型判断）
function M.get_icon(item)
    if not item then
        return "○"
    end

    -- 优先用用户注册图标
    if item.name and user_icons[item.name] then
        return user_icons[item.name]
    end

    -- 特殊类型优先级最高
    if item.type and icon_map[item.type] then
        return icon_map[item.type]
    end

    -- 根据积木类型返回图标
    local brick = BricksRegistry.get(item.name)
    local brick_type = item.brick_type or (brick and brick.brick_type)
    if brick_type and icon_map[brick_type] then
        return icon_map[brick_type]
    end

    -- 作为配置参数图标的默认
    if item.name then
        return icon_map.config_option
    end

    return "○"
end

return M

