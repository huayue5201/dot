local BricksRegistry = require("brickdag.core.bricks_registry")

local icon_map = {
  base = "🔧",
  frame = "⚙️",
  config_option = "⚡",
}

local user_icons = {}

local M = {}

function M.register_icon(name, icon)
  user_icons[name] = icon
end

function M.get_icon(item)
  if not item then return "○" end

  -- 优先用注册的用户图标
  if item.name and user_icons[item.name] then
    return user_icons[item.name]
  end

  -- 尝试从注册表找brick类型
  local brick = BricksRegistry.get(item.name)
  local brick_type = item.brick_type or (brick and brick.brick_type)

  if brick_type and icon_map[brick_type] then
    return icon_map[brick_type]
  end

  -- 作为配置参数的图标
  if item.name then
    return icon_map.config_option
  end

  return "○"
end

return M
