-- https://github.com/eero-lehtinen/oklch-color-picker.nvim

return {
	"eero-lehtinen/oklch-color-picker.nvim",
	event = "VeryLazy",
	version = "*",
	keys = {
		{
			"<leader>rv",
			function()
				require("oklch-color-picker").pick_under_cursor()
			end,
			desc = "Color pick under cursor",
		},
	},
	---@type oklch.Opts
	opts = {},
}
