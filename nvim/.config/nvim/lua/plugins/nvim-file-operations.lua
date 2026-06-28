-- https://github.com/Crysthamus/nvim-file-operations

return {
	"Crysthamus/nvim-file-operations",
	event = "VeryLazy",
	dependencies = {
		-- Uncomment whichever supported plugin(s) you use
		-- "nvim-tree/nvim-tree.lua",
		"nvim-neo-tree/neo-tree.nvim",
	},
	config = function()
		require("nvim-file-operations").setup()
	end,
}
