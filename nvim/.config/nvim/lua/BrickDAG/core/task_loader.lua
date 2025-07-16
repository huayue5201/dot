-- lua/BrickDAG/core/task_loader.lua
local uv = vim.loop
local task_filter = require("BrickDAG.utils.task_filter")

local M = {}

-- 加载原始任务（无过滤）
function M.load_raw_tasks()
	local tasks = {}
	local task_dir = vim.fn.stdpath("config") .. "/lua/tasks/"

	-- 检查目录是否存在
	if uv.fs_stat(task_dir) == nil then
		return tasks
	end

	-- 扫描任务目录
	local handle, err = uv.fs_scandir(task_dir)
	if not handle then
		vim.notify("无法扫描任务目录: " .. task_dir .. "\n错误: " .. (err or "未知"), vim.log.levels.ERROR)
		return tasks
	end

	-- 遍历文件
	while true do
		local name, typ = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		-- 加载.lua文件
		if name:match("%.lua$") then
			local modname = "tasks." .. name:gsub("%.lua$", "")

			local ok, task = pcall(require, modname)
			if ok and task then
				-- 基本验证
				if type(task) == "table" and task.name and task.type then
					table.insert(tasks, task)
				else
					vim.notify("任务配置无效: " .. modname, vim.log.levels.WARN)
				end
			else
				vim.notify("加载任务失败: " .. modname .. "\n错误: " .. tostring(task), vim.log.levels.ERROR)
			end
		end
	end

	return tasks
end

-- 加载并过滤任务（主接口）
function M.load_tasks()
	return task_filter.filter(M.load_raw_tasks())
end

return M
