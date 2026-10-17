-- https://github.com/antosha417/nvim-lsp-file-operations

return {
	"antosha417/nvim-lsp-file-operations",
	event = "VeryLazy",
	dependencies = {
		-- Uncomment whichever supported plugin(s) you use
		-- "nvim-tree/nvim-tree.lua",
		"nvim-neo-tree/neo-tree.nvim",
	},
	config = function()
		require("lsp-file-operations").setup()
	end,
}
