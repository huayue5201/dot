-- 保存
vim.keymap.set("n", "<leader>s", "<cmd>w<cr>", { desc = "保存" })

-- 代码块缩进
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "<", "<gv")

-- 删除buffer
vim.keymap.set("n", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })
vim.keymap.set("t", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set(
	"n",
	"<leader>oq",
	'<cmd>lua require("modules.quickfix_toggle").toggleQuickfix()<cr>',
	{ desc = "quickfix窗口", noremap = true, silent = true }
)

-- 切换loclist窗口
vim.keymap.set(
	"n",
	"<leader>ol",
	'<cmd>lua require("modules.loclist_toggle").toggleLocationList ()<cr>',
	{ desc = "loclist窗口", noremap = true, silent = true }
)
