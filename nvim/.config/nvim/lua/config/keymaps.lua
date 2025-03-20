vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { silent = true, desc = "向下移动选中的代码块" })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { silent = true, desc = "向上移动选中的代码块" })

vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })

vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { silent = true, desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>q", "<cmd>bdelete<cr>", { silent = true, desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<cr>", { silent = true, desc = "创建新的标签页" })

vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<cr>", { silent = true, desc = "关闭当前标签页" })

vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>", { silent = true, desc = "仅保留当前标签页" })

vim.keymap.set("n", "<leader>lm", "<cmd>Messages<cr>", { silent = true, desc = "查看历史消息" })

vim.keymap.set("n", "<localleader>q", "<cmd>Toggle quickfix<cr>", { desc = "切换 Quickfix 窗口" })

vim.keymap.set("n", "<localleader>l", "<cmd>Toggle loclist<cr>", { desc = "切换 Loclist 窗口" })

vim.keymap.set("n", "<A-b>", function()
	local file = vim.fn.expand("%:p") -- 获取当前文件的完整路径
	if file ~= "" then
		if vim.g.debug_file == file then
			-- 如果文件已经被标记，取消标记
			vim.g.debug_file = nil
			print("Debug file removed!")
		else
			-- 如果文件没有被标记，标记当前文件
			vim.g.debug_file = file
			print("Debug file set to: " .. file)
			require("neo-tree.sources.manager").refresh("filesystem")
		end
	else
		print("No file to mark!")
	end
end, { noremap = true, silent = true })

vim.keymap.set("n", "<leader>cp", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	print("Copied: " .. vim.fn.expand("%:p"))
end, { silent = true, desc = "复制绝对路径" })

vim.keymap.set("n", "<leader>cf", function()
	vim.fn.setreg("+", vim.fn.expand("%:f"))
	print("Copied: " .. vim.fn.expand("%:f"))
end, { silent = true, desc = "复制相对路径" })

vim.keymap.set("n", "<leader>ct", function()
	vim.fn.setreg("+", vim.fn.expand("%:t"))
	print("Copied: " .. vim.fn.expand("%:t"))
end, { silent = true, desc = "复制文件名" })

vim.keymap.set("i", "<Tab>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
	if next_char == nil then
		return "<Tab>"
	end
	if not vim.tbl_contains({ '"', "'", ")", "]", "}" }, next_char) then
		return "<Tab>"
	end
	return "<Right>"
end, { expr = true, desc = "插入模式下跳出括号或引号" })
