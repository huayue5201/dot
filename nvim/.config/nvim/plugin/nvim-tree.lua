-- https://github.com/nvim-tree/nvim-tree.lua

vim.g.later(function()
	vim.g.add({
		source = "nvim-tree/nvim-tree.lua",
		depends = { "nvim-tree/nvim-web-devicons" },
	})

	require("nvim-tree").setup()
	vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "文件树" })
end)
