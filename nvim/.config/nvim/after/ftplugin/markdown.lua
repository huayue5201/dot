-- 加载模块
local todo = require("utils.todo")

-- 设置本地映射（仅对当前缓冲区有效）
vim.keymap.set(
	"n",
	"<leader>tdn",
	todo.new_task_item,
	{ buffer = true, noremap = true, silent = true, desc = "新建任务" }
)

vim.keymap.set(
	"n",
	"<CR>",
	todo.toggle_task_state,
	{ buffer = true, noremap = true, silent = true, desc = "切换任务状态" }
)

todo.highlight_timestamp()
