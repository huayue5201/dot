-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "BufReadPre",
	dependencies = "nvim-telescope/telescope-fzf-native.nvim",
	keys = {
		{ "<leader>wb", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "Winbar" },
	},
	config = function()
		require("dropbar").setup()
	end,
}
