-- 通知系统 (notification.lua)

local M = {}

function M.task_started(task)
	vim.notify("🚀 开始任务: " .. task.label, vim.log.levels.INFO, {
		title = "TaskMaster",
		timeout = 2000,
		icon = "🚀",
	})
end

function M.task_completed(task, duration)
	vim.notify(string.format("✅ 任务完成: %s (%.1fs)", task.label, duration), vim.log.levels.INFO, {
		title = "TaskMaster",
		timeout = 3000,
		icon = "✅",
	})
end

function M.task_failed(task, duration)
	vim.notify(string.format("❌ 任务失败: %s (%.1fs)", task.label, duration), vim.log.levels.ERROR, {
		title = "TaskMaster",
		timeout = 4000,
		icon = "❌",
	})
end

return M
