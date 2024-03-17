-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "VeryLazy",
	dependencies = "nvim-telescope/telescope-fzf-native.nvim",
	keys = {
		{ "<leader>ew", desc = "Winbar" },
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
		vim.keymap.set("n", "<leader>ew", "<cmd>lua require('dropbar.api').pick()<cr>", { desc = "Winbar" })
	end,
}
