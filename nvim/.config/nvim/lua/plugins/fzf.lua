-- https://github.com/junegunn/fzf.vim

vim.g.later(function()
	vim.g.add({
		source = "junegunn/fzf.vim",
		depends = {
			"junegunn/fzf",
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
