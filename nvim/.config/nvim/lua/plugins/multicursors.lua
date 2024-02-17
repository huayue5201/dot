-- https://github.com/smoka7/multicursors.nvim

return {
	"smoka7/multicursors.nvim",
	dependencies = {
		"anuvyklack/hydra.nvim",
	},
	opts = {},
	cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
	keys = {
		{
			mode = { "v", "n" },
			"<Leader>i",
			"<cmd>MCstart<cr>",
			desc = "Create a selection for selected text or word under the cursor",
		},
	},
	config = function()
		require("multicursors").setup({
			hint_config = {
				border = "rounded",
				position = "bottom-right",
			},
			generate_hints = {
				normal = true,
				insert = true,
				extend = true,
				config = {
					column_count = 1,
				},
			},
		})
	end,
}
