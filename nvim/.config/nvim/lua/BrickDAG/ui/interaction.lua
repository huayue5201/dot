-- ui/interaction.lua
local task_loader = require("BrickDAG.core.task_loader")
local runner = require("BrickDAG.core.task_runner")

local M = {}

--- 选择并运行任务
function M.pick_and_run()
	local all_tasks = task_loader.load_tasks()

	if #all_tasks == 0 then
		vim.notify("未找到任何任务", vim.log.levels.WARN)
		return
	end

	local items = {}
	local task_map = {}

	for _, task in ipairs(all_tasks) do
		if type(task.name) == "string" then
			table.insert(items, task.name)
			task_map[task.name] = task
		end
	end

	vim.ui.select(items, {
		prompt = "选择要执行的任务:",
	}, function(choice)
		if not choice then
			return
		end

		local task = task_map[choice]
		if not task then
			vim.notify("选择的任务不存在", vim.log.levels.ERROR)
			return
		end

		-- 运行任务
		runner.run({ task }, function(success, err)
			if success then
				vim.notify("✅ 任务成功执行: " .. task.name)
			else
				vim.notify("❌ 任务执行失败: " .. (err or "未知错误"), vim.log.levels.ERROR)
			end
		end)
	end)
end

return M
