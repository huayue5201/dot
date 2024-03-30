-- 代码块缩进
map("v", ">", ">gv")
map("v", "<", "<gv")

--  指向黑洞寄存器
map("n", "x", '"_x')
map("n", "c", '"_c')
-- 更智能的dd删除
map("n", "dd", function()
	if vim.fn.getline(".") == "" then
		return '"_dd'
	end
	return "dd"
end, { expr = true })

-- 修改光标下的word
map({ "n" }, "<leader>rc", "*``cgn", { desc = "修改文本" })

-- 保存
map({ "n" }, "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 删除buffer
map({ "n" }, "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 切换buffer
-- keymap("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区" })
-- keymap("n", "<S-TAB>", "<cmd>bprev<cr>", { desc = "上一个缓冲区" })

-- tab操作
map("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
map("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })

-- 删除标记
map("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
map("n", "<leader>q", '<cmd>lua require("util.quickfix_toggle").toggleQuickfix()<cr>', { desc = "quickfix窗口" })

-- 切换loclist窗口
map("n", "<leader>l", '<cmd>lua require("util.loclist_toggle").toggleLocationList ()<cr>', { desc = "loclist窗口" })

-- 插入模式下TAB可以跳出()[]....
map("i", "<Tab>", function()
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

-- 自动关闭？/搜索匹配高亮
vim.on_key(function(char)
	if vim.fn.mode() == "n" then
		local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
		if vim.opt.hlsearch:get() ~= new_hlsearch then
			vim.opt.hlsearch = new_hlsearch
		end
	end
end, vim.api.nvim_create_namespace("auto_hlsearch"))
