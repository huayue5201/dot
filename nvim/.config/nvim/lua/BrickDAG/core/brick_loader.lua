-- lua/brickdag/core/brick_loader.lua

local uv = vim.loop
local registry = require("brickdag.core.bricks_registry")
local interface = require("brickdag.core.interface")

local M = {}

--- 加载所有积木模块（基础积木和框架积木）
--- 根据目录结构分别加载 `base` 和 `frame` 类型积木，
--- 并调用对应的接口验证函数，确保模块符合契约，
--- 验证通过后注册到积木注册表中
function M.load_all()
	-- 获取积木根目录路径
	local base_path = vim.fn.stdpath("config") .. "/lua/brickdag/bricks/"

	-- 积木目录和对应类型配置
	local brick_dirs = {
		{ type = "base", path = base_path .. "base/" },
		{ type = "frame", path = base_path .. "frame/" },
	}

	-- 遍历基础积木和框架积木目录
	for _, dir_info in ipairs(brick_dirs) do
		local brick_type = dir_info.type
		local dir_path = dir_info.path

		-- 扫描目录文件
		local handle = uv.fs_scandir(dir_path)
		if not handle then
			vim.notify("无法扫描积木目录: " .. dir_path, vim.log.levels.ERROR)
			goto continue
		end

		while true do
			-- 读取目录下的文件名
			local name, typ = uv.fs_scandir_next(handle)
			if not name then
				break
			end

			-- 只加载 lua 文件
			if name:match("%.lua$") then
				-- 构造模块名
				local modname = "brickdag.bricks." .. brick_type .. "." .. name:gsub("%.lua$", "")

				-- 保护式加载模块，避免异常崩溃
				local ok, mod = pcall(require, modname)
				if not ok then
					vim.notify("加载积木失败: " .. modname, vim.log.levels.ERROR)
				else
					-- 根据积木类型调用对应的接口验证函数
					local valid, err
					if brick_type == "base" then
						valid, err = interface.validate_base_brick(mod)
					else
						valid, err = interface.validate_frame_brick(mod)
					end

					-- 验证通过则注册积木
					if valid then
						if brick_type == "base" then
							registry.register_base_brick(mod)
						else
							registry.register_frame_brick(mod)
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

		::continue::
	end
end

return M
