vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { silent = true, desc = "向下移动选中的代码块" })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { silent = true, desc = "向上移动选中的代码块" })

vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })

vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })

vim.keymap.set("n", "<c-s>", "<cmd>w<cr>", { silent = true, desc = "保存buffer" })

-- vim.keymap.set("n", "<Leader>q", ":bp|bd#<cr>", { silent = true, desc = "退出buffer" })
vim.keymap.set("n", "<Leader>q", "<cmd>bd<cr>", { silent = true, desc = "退出buffer" })

vim.keymap.set("n", "<leader>ttn", "<cmd>$tabnew<cr>", { silent = true, desc = "创建新的标签页" })

vim.keymap.set("n", "<leader>ttr", "<cmd>tabclose<cr>", { silent = true, desc = "关闭当前标签页" })

vim.keymap.set("n", "<leader>ttR", "<cmd>tabonly<cr>", { silent = true, desc = "仅保留当前标签页" })

-- vim.keymap.set("n", "<leader>lm", "<cmd>Messages<cr>", { silent = true, desc = "查看历史消息" })

vim.keymap.set("n", "<localleader>q", "<cmd>Toggle quickfix<cr>", { desc = "Toggle Quickfix" })

vim.keymap.set("n", "<localleader>l", "<cmd>Toggle loclist<cr>", { desc = "Toggle Loclist" })

vim.keymap.set({ "v", "n" }, "<A-v>", '"+p', { silent = true, desc = "粘贴<系统剪贴板>" })

vim.keymap.set("n", "<leader>yp", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	print("Copied: " .. vim.fn.expand("%:p"))
end, { silent = true, desc = "复制绝对路径" })

vim.keymap.set("n", "<leader>yf", function()
	vim.fn.setreg("+", vim.fn.expand("%:f"))
	print("Copied: " .. vim.fn.expand("%:f"))
end, { silent = true, desc = "复制相对路径" })

vim.keymap.set("n", "<leader>yt", function()
	vim.fn.setreg("+", vim.fn.expand("%:t"))
	print("Copied: " .. vim.fn.expand("%:t"))
end, { silent = true, desc = "复制文件名" })

vim.keymap.set("n", "<leader>ram", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
end, { desc = "Delete all marks (lowercase and uppercase)" })

vim.keymap.set("n", "<Leader>raw", function()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_dir = vim.fn.fnamemodify(vim.fn.bufname(current_buf), ":p:h") -- 获取当前缓冲区的目录
	-- 遍历所有窗口
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		if win_id ~= current_win then
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			local buf_dir = vim.fn.fnamemodify(vim.fn.bufname(buf_id), ":p:h") -- 获取窗口缓冲区的目录
			-- 如果缓冲区不在当前目录，则删除该窗口
			if buf_dir ~= current_dir then
				vim.api.nvim_win_close(win_id, true) -- 关闭该窗口
			end
		end
	end
	print("Deleted windows outside the current directory!")
end, { silent = true, desc = "删除当前窗口外的所有窗口" })
