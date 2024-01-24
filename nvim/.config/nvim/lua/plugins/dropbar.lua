-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = { "BufReadPost" },
	-- optional, but required for fuzzy finder support
	dependencies = {
		"nvim-telescope/telescope-fzf-native.nvim",
	},
	keys = {
		{ "<leader>os", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "选择bar" },
	},
}
