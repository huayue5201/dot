-- https://github.com/kylechui/nvim-surround

return {
	"kylechui/nvim-surround",
	keys = { "cs", "ds", "ys" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-treesitter/nvim-treesitter-textobjects",
	},

	config = function()
		require("nvim-surround").setup()
	end,
}
