-- 加载模块
local todo = require("utils.todo")

-- 设置本地映射（仅对当前缓冲区有效）
vim.keymap.set(
	"i",
	"<S-CR>",
	todo.new_task_item,
	{ buffer = true, noremap = true, silent = true, desc = "新建任务" }
)

_G._new_task_item = function()
	todo.new_task_item()
end
vim.keymap.set("n", "<leader>tdn", function()
	vim.o.operatorfunc = "v:lua._new_task_item" -- 使用一个正确的函数名
	vim.cmd.normal("g@l") -- 执行操作符
end, { buffer = true, silent = true, desc = "新建任务" })

_G._convert_line_to_task = function()
	todo.convert_line_to_task()
end
vim.keymap.set("n", "<leader>tdt", function()
	vim.o.operatorfunc = "v:lua._convert_line_to_task" -- 使用一个正确的函数名
	vim.cmd.normal("g@l") -- 执行操作符
end, { buffer = true, silent = true, desc = "转化为任务" })

vim.keymap.set(
	"n",
	"<CR>",
	todo.toggle_task_state,
	{ buffer = true, noremap = true, silent = true, desc = "切换任务状态" }
)

todo.highlight_timestamp()
