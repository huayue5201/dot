-- core/bricks_registry.lua
local BricksRegistry = {}
BricksRegistry.__index = BricksRegistry

-- 存储已注册的积木模块和框架
local base_bricks = {} -- 基础积木
local frame_bricks = {} -- 框架积木

-- 注册基础积木
function BricksRegistry.register_base_brick(brick)
	if not brick.name then
		error("Brick must have a name field")
	end
	base_bricks[brick.name] = brick
end

-- 注册框架积木
function BricksRegistry.register_frame_brick(frame)
	if not frame.name then
		error("Frame must have a name field")
	end
	frame_bricks[frame.name] = frame
end

-- 获取积木（优先框架）
function BricksRegistry.get(name)
	return frame_bricks[name] or base_bricks[name]
end

-- 获取框架积木
function BricksRegistry.get_frame(name)
	return frame_bricks[name]
end

-- 清除所有积木（用于测试）
function BricksRegistry.clear()
	base_bricks = {}
	frame_bricks = {}
end

-- 新增：运行时注册基础积木
--- @param brick table BaseBrick
function BricksRegistry.runtime_register_base_brick(brick)
	if not brick.name then
		error("Brick must have a name field")
	end

	-- 确保接口符合要求
	local valid, err = require("brickdag-next.core.interface").validate_base_brick(brick)
	if not valid then
		error("Invalid base brick: " .. (err or "unknown error"))
	end

	base_bricks[brick.name] = brick
	vim.notify("运行时注册基础积木: " .. brick.name, vim.log.levels.INFO)
end

-- 新增：运行时注册框架积木
--- @param frame table FrameBrick
function BricksRegistry.runtime_register_frame_brick(frame)
	if not frame.name then
		error("Frame must have a name field")
	end

	-- 确保接口符合要求
	local valid, err = require("brickdag-next.core.interface").validate_frame_brick(frame)
	if not valid then
		error("Invalid frame brick: " .. (err or "unknown error"))
	end

	frame_bricks[frame.name] = frame
	vim.notify("运行时注册框架积木: " .. frame.name, vim.log.levels.INFO)
end

return {
	register_base_brick = BricksRegistry.register_base_brick,
	register_frame_brick = BricksRegistry.register_frame_brick,
	get = BricksRegistry.get,
	get_frame = BricksRegistry.get_frame,
	clear = BricksRegistry.clear,
	runtime_register_base_brick = BricksRegistry.runtime_register_base_brick,
	runtime_register_frame_brick = BricksRegistry.runtime_register_frame_brick,
}
