-- https://github.com/otavioschwanck/arrow.nvim

return {
	"otavioschwanck/arrow.nvim",
	event = "VeryLazy",
	dependencies = {
		{ "nvim-tree/nvim-web-devicons" },
	},
	config = function()
		require("arrow").setup({
			show_icons = true,
			leader_key = "<leader>,", -- Recommended to be a single key
			buffer_leader_key = "m", -- Per Buffer Mappings
		})
	end,
}
