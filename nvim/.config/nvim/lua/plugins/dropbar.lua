-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	lazy = false,
	dependencies = "nvim-telescope/telescope-fzf-native.nvim",
	keys = {
		{ "<leader>wb", "<cmd>lua require('dropbar.api').pick()<cr>", desc = "Winbar" },
	},
	config = function()
		require("dropbar").setup({
			icons = {
				enable = true,
				ui = {
					bar = {
						separator = " ➭ ",
						extends = "…",
					},
					menu = {
						separator = " ",
						indicator = "↪",
					},
				},
			},
		})
	end,
}
