-- 保存
vim.keymap.set("n", "<leader>s", "<cmd>w<cr>", { desc = "保存" })

-- 代码块缩进
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "<", "<gv")

-- 删除buffer
vim.keymap.set("n", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })
vim.keymap.set("t", "<c-q>", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 打开quickfix窗口
vim.keymap.set("n", "<leader>oq", "<cmd>copen<cr>", { desc = "打开quickfix" })
-- 关闭quickfix窗口
vim.keymap.set("n", "<leader>cq", "<cmd>cclose<cr>", { desc = "关闭quickfix" })

-- 删除所有标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除所有标记" })

-- 一键全选
vim.keymap.set("n", "<leader>gg", "ggVG", { desc = "全选" })

-- 正常模式下按 ESC 取消高亮显示
vim.keymap.set("n", "<ESC>", "<cmd>nohlsearch<cr>")
