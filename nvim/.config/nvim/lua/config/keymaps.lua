-- 设置前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- 代码块缩进
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "<", "<gv")

--  指向黑洞寄存器
vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "c", '"_c')

-- 更智能的dd删除
vim.keymap.set("n", "dd", function()
	if vim.fn.getline(".") == "" then
		return '"_dd'
	end
	return "dd"
end, { expr = true })

-- 将绝对路径复制到剪贴板
vim.keymap.set("n", "<leader>ya", ':let @+ = expand("%:p")<CR>')
-- 将相对路径复制到剪贴板
vim.keymap.set("n", "<leader>yr", ':let @+ = expand("%:f")<CR>')
-- 将文件名复制到剪贴板
vim.keymap.set("n", "<leader>yf", ':let @+ = expand("%:t")<CR>')

-- 修改光标下的word
vim.keymap.set("n", "<leader>rc", "*``cgn", { desc = "修改文本" })
-- 修改选中文本
vim.keymap.set("x", "<leader>rc", [[y<cmd>let @/ = escape(@", '/')<cr>"_cgn]])

-- 保存
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 删除buffer
vim.keymap.set("n", "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 切换buffer
-- keymap("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区" })
-- keymap("n", "<S-TAB>", "<cmd>bprev<cr>", { desc = "上一个缓冲区" })

-- tab操作
vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 退出终端
-- map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- 切换quickfix窗口
vim.keymap.set("n", "<leader>q", '<cmd>lua require("user.keybindings").toggleQuickfix()<cr>')
-- 上一条匹配结果
vim.keymap.set("n", "]q", "<cmd>cprev<cr>")
-- 下一条匹配结果
vim.keymap.set("n", "[q", "<cmd>cnext<cr>")
-- 切换loclist窗口
vim.keymap.set("n", "<leader>l", '<cmd>lua require("user.keybindings").toggleLocationList ()<cr>')
-- 上一条匹配结果
vim.keymap.set("n", "]l", "<cmd>lnext<cr>")
-- 下一条匹配结果
vim.keymap.set("n", "[l", "<cmd>lprev<cr>")

-- 插入模式下TAB可以跳出()[]....
vim.keymap.set("i", "<Tab>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
	if next_char == "" then
		return "<Tab>"
	end
	local special_chars = { '"', "'", ")", "]", "}", ">" }
	if not vim.tbl_contains(special_chars, next_char) then
		return "<Tab>"
	end
	return "<Right>"
end, { expr = true })
