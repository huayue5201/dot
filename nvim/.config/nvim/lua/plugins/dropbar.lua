-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "BufReadPost",
	dependencies = "nvim-telescope/telescope-fzf-native.nvim",
	keys = {
		{ "gb", desc = "Winbar" },
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
		vim.keymap.set("n", "gb", "<cmd>lua require('dropbar.api').pick()<cr>", { desc = "Winbar" })
	end,
}
