-- 初始化任务系统 init.lua

local M = {}

function M.setup()
	local task_manager = require("TaskMaster.task_manager"):new()
	task_manager:init()

	vim.keymap.set("n", "<leader>oz", "<cmd>TaskMaster<cr>", { desc = "任务中心" })
	vim.keymap.set("n", "<leader>or", function()
		task_manager:run_task_interactive()
	end, { desc = "运行任务" })
	vim.keymap.set("n", "<leader>oq", "<cmd>TaskQueueUI<cr>", { desc = "任务队列" })
	vim.keymap.set("n", "<leader>oh", function()
		task_manager:show_history_ui()
	end, { desc = "任务历史" })
	vim.keymap.set("n", "<leader>oc", "<cmd>TaskCancel<cr>", { desc = "取消任务" })
	vim.keymap.set("n", "<leader>ol", "<cmd>TaskList<cr>", { desc = "任务列表" })
	vim.keymap.set("n", "<leader>op", "<cmd>TaskPicker<cr>", { desc = "任务选择器" })
	vim.keymap.set("n", "<leader>oQ", "<cmd>TaskQueueAdd<cr>", { desc = "添加到队列" })
	vim.keymap.set("n", "<leader>oR", "<cmd>TaskReload<cr>", { desc = "重新加载任务" })
	vim.keymap.set("n", "<leader>oe", "<cmd>TaskEnvSet ", { desc = "设置环境变量" })
end

return M
