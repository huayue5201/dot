-- https://github.com/kevinhwang91/nvim-bqf

vim.g.later(function()
	vim.g.add({
		source = "kevinhwang91/nvim-bqf",
		depends = {
			"nvim-treesitter/nvim-treesitter",
		},
	})
end)
