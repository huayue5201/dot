-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = { "BufReadPre" },
	keys = {
		{ "<leader>or", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "选择bar" },
	},
}
