-- bricks/brick_loader.lua
local uv = vim.loop
local registry = require("BrickDAG.core.bricks_registry")
local interface = require("BrickDAG.core.interface")

local M = {}

-- 排除列表：这些文件不是积木，不应注册
local exclude_files = {
	-- ["brick_loader.lua"] = true,
	-- ["registry.lua"] = true,
}

-- 加载所有积木模块
function M.load_all()
	-- 获取bricks目录路径
	local base_path = vim.fn.stdpath("config") .. "/lua/BrickDAG/bricks/"

	local handle = uv.fs_scandir(base_path)
	if not handle then
		vim.notify("无法扫描bricks目录: " .. base_path, vim.log.levels.ERROR)
		return
	end

	while true do
		local name, typ = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		-- 只加载.lua文件，且不在排除列表
		if name:match("%.lua$") and not exclude_files[name] then
			local modname = "BrickDAG.bricks." .. name:gsub("%.lua$", "")

			local ok, mod = pcall(require, modname)
			if not ok then
				vim.notify("加载积木失败: " .. modname, vim.log.levels.ERROR)
			else
				-- 接口契约验证
				local valid, err
				if mod.brick_type == "base" then
					valid, err = interface.validate_base_brick(mod)
				elseif mod.brick_type == "frame" then
					valid, err = interface.validate_frame_brick(mod)
				end

				if valid then
					if mod.brick_type == "base" then
						registry.register_base_brick(mod)
						vim.notify("已注册基础积木: " .. mod.name, vim.log.levels.INFO)
					elseif mod.brick_type == "frame" then
						registry.register_frame_brick(mod)
						vim.notify("已注册框架积木: " .. mod.name, vim.log.levels.INFO)
					end
				else
					vim.notify(
						"积木接口验证失败: " .. modname .. " - " .. (err or "未知错误"),
						vim.log.levels.ERROR
					)
				end
			end
		end
	end
end

return M
