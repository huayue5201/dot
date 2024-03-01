-- 把空格键设置为前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 保存
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 代码块缩进
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "<", "<gv")

-- 删除buffer
vim.keymap.set("n", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })
vim.keymap.set("t", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 切换buffer
vim.keymap.set("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区" })
vim.keymap.set("n", "<S-TAB>", "<cmd>bnext<cr>", { desc = "上一个缓冲区" })

-- tab操作
vim.keymap.set("n", "<leader>ta", "<cmd>$tabnew<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { noremap = true })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { noremap = true })
vim.keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { noremap = true })
-- move current tab to previous position
vim.keymap.set("n", "<leader>tmp", "<cmd>-tabmove<CR>", { noremap = true })
-- move current tab to next position
vim.keymap.set("n", "<leader>tmn", "<cmd>+tabmove<CR>", { noremap = true })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set(
   "n",
   "<leader>oq",
   '<cmd>lua require("utils.quickfix_toggle").toggleQuickfix()<cr>',
   { desc = "quickfix窗口", noremap = true, silent = true }
)

-- 切换loclist窗口
vim.keymap.set(
   "n",
   "<leader>ol",
   '<cmd>lua require("utils.loclist_toggle").toggleLocationList ()<cr>',
   { desc = "loclist窗口", noremap = true, silent = true }
)
