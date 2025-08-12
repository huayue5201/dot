-- core/bricks_registry.lua
local Interface = require("brickdag.core.interface")

local BricksRegistry = {}
BricksRegistry.__index = BricksRegistry

-- 存储已注册的积木模块和框架
local base_bricks = {} -- 基础积木
local frame_bricks = {} -- 框架积木

--- 内部注册通用方法
--- @param store table 存储表
--- @param brick table 积木对象
--- @param validator? fun(brick: table): boolean, string 验证函数（可选）
--- @param notify_prefix? string 通知前缀（可选）
local function register_brick(store, brick, validator, notify_prefix)
    if not brick.name then
        error("Brick must have a name field")
    end

    if validator then
        local valid, err = validator(brick)
        if not valid then
            error("Invalid brick: " .. (err or "unknown error"))
        end
    end

    store[brick.name] = brick

    if notify_prefix then
        vim.notify(notify_prefix .. brick.name, vim.log.levels.INFO)
    end
end

-- 静态注册
function BricksRegistry.register_base_brick(brick)
    register_brick(base_bricks, brick)
end

function BricksRegistry.register_frame_brick(frame)
    register_brick(frame_bricks, frame)
end

-- 运行时注册
function BricksRegistry.runtime_register_base_brick(brick)
    register_brick(base_bricks, brick, Interface.validate_base_brick, "运行时注册基础积木: ")
end

function BricksRegistry.runtime_register_frame_brick(frame)
    register_brick(frame_bricks, frame, Interface.validate_frame_brick, "运行时注册框架积木: ")
end

-- 获取基础积木
function BricksRegistry.get_base_brick(name)
    return base_bricks[name]
end

-- 获取框架积木
function BricksRegistry.get_frame(name)
    return frame_bricks[name]
end

-- 获取所有基础积木名称
function BricksRegistry.get_base_brick_names()
    local names = {}
    for name in pairs(base_bricks) do
        table.insert(names, name)
    end
    return names
end

-- 返回当前所有注册的基础积木（完整表）
function BricksRegistry.get_all_base_bricks()
    return base_bricks
end

-- 返回当前所有注册的框架积木（完整表）
function BricksRegistry.get_all_frame_bricks()
    return frame_bricks
end

-- 清除所有积木（用于测试）
function BricksRegistry.clear()
    base_bricks = {}
    frame_bricks = {}
end

return {
    register_base_brick = BricksRegistry.register_base_brick,
    register_frame_brick = BricksRegistry.register_frame_brick,
    runtime_register_base_brick = BricksRegistry.runtime_register_base_brick,
    runtime_register_frame_brick = BricksRegistry.runtime_register_frame_brick,
    get_frame = BricksRegistry.get_frame,
    get_base_brick = BricksRegistry.get_base_brick,
    get_base_brick_names = BricksRegistry.get_base_brick_names,
    get_all_base_bricks = BricksRegistry.get_all_base_bricks,
    get_all_frame_bricks = BricksRegistry.get_all_frame_bricks,
    clear = BricksRegistry.clear,
}

