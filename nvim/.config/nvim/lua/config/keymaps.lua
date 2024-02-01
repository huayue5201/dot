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
	{ noremap = true, silent = true }
)

-- 切换loclist窗口
vim.keymap.set(
	"n",
	"<leader>ol",
	'<cmd>lua require("modules.loclist_toggle").toggleLocationList ()<cr>',
	{ noremap = true, silent = true }
)
-- 正常模式下按 ESC 取消高亮显示
-- vim.keymap.set("n", "<ESC>", "<cmd>nohlsearch<cr>")
