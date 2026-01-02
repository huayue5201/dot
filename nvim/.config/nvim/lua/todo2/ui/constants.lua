-- lua/todo/ui/constants.lua
local M = {}

M.KEYMAPS = {
	close = { "n", "q", "关闭窗口" },
	refresh = { "n", "<C-r>", "刷新显示" },
	toggle = { "n", "<cr>", "切换任务状态" },
	toggle_insert = { "i", "<C-CR>", "切换任务状态" },
	toggle_selected = { { "v", "x" }, "<cr>", "批量切换任务状态" }, -- 合并模式
	new_task = { "n", "<leader>nt", "新建任务" },
	new_subtask = { "n", "<leader>nT", "新建子任务" },
	new_sibling = { "n", "<leader>ns", "新建平级任务" },
}

M.TODO_FILE_PATTERN = "*.todo.md"
M.TODO_DIR = "~/.todo-files/"

return M
