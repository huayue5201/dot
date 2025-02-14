-- https://github.com/kylechui/nvim-surround

vim.g.later(function()
	vim.g.add({
		source = "kylechui/nvim-surround",
		depends = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-treesitter/nvim-treesitter-textobjects",
		},
	})

	require("nvim-surround").setup()
end)
