-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "BufReadPre",
	keys = {
		{ "<leader>b", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "Winbar" },
	},
}
