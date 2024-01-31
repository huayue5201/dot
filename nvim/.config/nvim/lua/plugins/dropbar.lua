-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "VeryLazy",
	keys = {
		{ "<leader>os", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "选择bar" },
	},
}
