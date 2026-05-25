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
		vim.keymap.set("n", "H", require("arrow.persist").previous)
		vim.keymap.set("n", "L", require("arrow.persist").next)
		vim.keymap.set("n", "<C-m>", require("arrow.persist").toggle)
	end,
}
