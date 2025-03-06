-- https://github.com/junegunn/fzf.vim

vim.g.later(function()
	vim.g.add({
		source = "junegunn/fzf.vim",
	})

	vim.keymap.set("n", "<leader>ff", "<cmd>Files<cr>", { desc = "查找文件" })
	vim.keymap.set("n", "<leader>fb", "<cmd>Buffers<cr>", { desc = "切换缓冲区" })
	vim.keymap.set("n", "<leader>fg", "<cmd>Rg<cr>", { desc = "使用 Ripgrep 搜索" })
	vim.keymap.set("n", "<leader>fm", "<cmd>Marks<cr>", { desc = "查看书签" })
	vim.keymap.set("n", "<leader>fo", "<cmd>History<cr>", { desc = "查看历史记录" })
	vim.keymap.set("n", "<leader>fw", "<cmd>Windows<cr>", { desc = "查看历史记录" })
end)
