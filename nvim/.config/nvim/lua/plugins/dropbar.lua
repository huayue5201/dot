-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	event = "BufReadPost",
	dependencies = {
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
	},
	keys = {
		{ "<Leader>;", desc = "Winbar" },
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
		local dropbar_api = require("dropbar.api")
		vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
		vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
		vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
	end,
}
