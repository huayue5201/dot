-- https://gitlab.com/yorickpeterse/nvim-window

return {
	"yorickpeterse/nvim-window",
	event = { "WinNew" },
	keys = {
		{ "<C-w>n", "<cmd>lua require('nvim-window').pick()<cr>", mode = { "n", "t" }, desc = "选择窗口" },
	},
	opts = {},
}
