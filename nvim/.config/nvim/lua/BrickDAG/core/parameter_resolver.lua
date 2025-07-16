-- lua/BrickDAG/core/parameter_resolver.lua

local bricks_registry = require("BrickDAG.core.bricks_registry")

local M = {}

--- 解析任务中的所有积木参数
--- @param config table 原始任务配置
--- @param context table 上下文（如 project_root）
--- @return table resolved_params
function M.resolve_parameters(config, context)
	local resolved = {}

	for key, value in pairs(config) do
		-- 获取对应积木
		local brick = bricks_registry.get_base_brick(key)
		if brick and brick.resolve then
			local ok, result = pcall(brick.resolve, value, context or {})
			if ok then
				resolved[key] = result
			else
				resolved[key] = { "<解析失败>", result }
			end
		end
	end

	return resolved
end

return M
