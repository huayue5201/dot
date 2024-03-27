-- 代码块缩进
keymap("v", ">", ">gv")
keymap("v", "<", "<gv")

--  指向黑洞寄存器
keymap("n", "x", '"_x')
keymap("n", "c", '"_c')
-- 更智能的dd删除
keymap("n", "dd", function()
	if vim.fn.getline(".") == "" then
		return '"_dd'
	end
	return "dd"
end, { expr = true })

-- 修改光标下的word
keymap({ "n" }, "<leader>rc", "*``cgn", { desc = "修改文本" })

-- 保存
keymap({ "n" }, "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 删除buffer
keymap({ "n" }, "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 切换buffer
-- keymap("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区" })
-- keymap("n", "<S-TAB>", "<cmd>bprev<cr>", { desc = "上一个缓冲区" })

-- tab操作
keymap("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
keymap("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
keymap("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })

-- 删除标记
keymap("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
keymap(
	"n",
	"<leader>q",
	'<cmd>lua require("modules.quickfix_toggle").toggleQuickfix()<cr>',
	{ desc = "quickfix窗口" }
)

-- 切换loclist窗口
keymap(
	"n",
	"<leader>l",
	'<cmd>lua require("modules.loclist_toggle").toggleLocationList ()<cr>',
	{ desc = "loclist窗口" }
)

-- 插入模式下TAB可以跳出()[]....
keymap("i", "<Tab>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
	if next_char == nil then
		return "<Tab>"
	end

	if not vim.tbl_contains({ '"', "'", ")", "]", "}", ">" }, next_char) then
		return "<Tab>"
	end

	return "<Right>"
end, { expr = true })
