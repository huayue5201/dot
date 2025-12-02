-- https://github.com/kevinhwang91/nvim-bqf

return {
	"kevinhwang91/nvim-bqf",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		{
			"junegunn/fzf",
			build = function()
				vim.fn["fzf#install"]()
			end,
		},
	},
	ft = "qf",
}
