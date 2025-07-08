-- core/task_loader.lua
local uv = vim.loop

local M = {}

-- 加载任务配置
--- @return table[] 任务列表
function M.load_tasks()
	local tasks = {}
	local task_dir = vim.fn.stdpath("config") .. "/lua/tasks/"

	-- 检查目录是否存在
	if uv.fs_stat(task_dir) == nil then
		vim.notify("任务目录不存在: " .. task_dir, vim.log.levels.WARN)
		return tasks
	end

	local handle = uv.fs_scandir(task_dir)
	if not handle then
		vim.notify("无法扫描任务目录: " .. task_dir, vim.log.levels.ERROR)
		return tasks
	end

	while true do
		local name, typ = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		if name:match("%.lua$") then
			local modname = "tasks." .. name:gsub("%.lua$", "")

			local ok, task = pcall(require, modname)
			if ok and task then
				table.insert(tasks, task)
				vim.notify("已加载任务: " .. task.name, vim.log.levels.INFO)
			else
				vim.notify("加载任务失败: " .. modname, vim.log.levels.ERROR)
			end
		end
	end

	return tasks
end

return M
