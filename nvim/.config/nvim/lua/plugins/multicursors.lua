-- https://github.com/smoka7/multicursors.nvim

return {
	"smoka7/multicursors.nvim",
	event = "VeryLazy",
	dependencies = {
		"anuvyklack/hydra.nvim",
	},
	opts = {},
	cmd = { "MCstart", "MCvisual", "MCclear", "MCpattern", "MCvisualPattern", "MCunderCursor" },
	keys = {
		{
			mode = { "v", "n" },
			"<leader>ii",
			"<cmd>MCunderCursor<cr>",
			desc = "选择光标下的字符",
		},
		{
			mode = { "v", "n" },
			"<leader>iw",
			"<cmd>MCstart<cr>",
			desc = "选择光标下的单词",
		},
	},
}
