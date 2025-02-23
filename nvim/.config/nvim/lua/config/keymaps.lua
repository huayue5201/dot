-- 代码块移动
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- 指向黑洞寄存器
vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "c", '"_c')

-- 更智能的dd删除
vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true })

-- 将绝对路径复制到剪贴板
vim.keymap.set("n", "<leader>yp", ':let @+ = expand("%:p")<CR>')
-- 将相对路径复制到剪贴板
vim.keymap.set("n", "<leader>yf", ':let @+ = expand("%:f")<CR>')
-- 将文件名复制到剪贴板
vim.keymap.set("n", "<leader>yt", ':let @+ = expand("%:t")<CR>')

-- 搜索与替换
vim.keymap.set("n", "crc", "*``cgn", { desc = "修改文本" })
-- 搜索光标下的单词
vim.keymap.set("n", "g/", function()
	local last_search = vim.fn.getreg("/")
	vim.cmd("vimgrep /" .. last_search .. "/j %")
	vim.cmd("cw")
end, { desc = "Search using vimgrep and open quickfix" })

-- 保存
vim.keymap.set("n", "<leader>s", "<cmd>w<cr>", { desc = "保存" })

-- 终端映射
vim.keymap.set("n", "<leader>te", ":botright new | resize 20 | terminal<CR>")

-- tab操作
vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>DeleteMarks<cr>", { desc = "删除标记" })
vim.keymap.set("n", "<leader>dm", "<cmd>DelAllMarks<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set("n", "<leader>q", "<cmd>ToggleQuickfix<cr>", { desc = "quickfix切换" })

-- 切换loclist窗口
vim.keymap.set("n", "<leader>l", "<cmd>ToggleLoclist<cr>", { desc = " LoclistToggle" })

-- -- 插入模式下TAB可以跳出()[]....
-- vim.keymap.set("i", "<Tab>", function()
-- 	local cursor = vim.api.nvim_win_get_cursor(0)
-- 	local line = vim.api.nvim_get_current_line()
-- 	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
-- 	if next_char == nil then
-- 		return "<Tab>"
-- 	end
-- 	if not vim.tbl_contains({ '"', "'", ")", "]", "}" }, next_char) then
-- 		return "<Tab>"
-- 	end
-- 	return "<Right>"
-- end, { expr = true })
