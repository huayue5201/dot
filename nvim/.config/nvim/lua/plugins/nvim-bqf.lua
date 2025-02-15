-- https://github.com/kevinhwang91/nvim-bqf

vim.g.later(function()
	vim.g.add({
		source = "kevinhwang91/nvim-bqf",
		depends = {
			"junegunn/fzf",
			"nvim-treesitter/nvim-treesitter",
		},
	})

	vim.g.add({
		source = "junegunn/fzf",
		hooks = {
			post_checkout = function()
				vim.fn["fzf#install"]()
			end,
		},
	})
end)
