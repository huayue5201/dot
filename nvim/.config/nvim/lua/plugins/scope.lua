-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	keys = {
		"<leader>ta",
		"<leader>tt",
		desc = "移动buferr到别的tabs",
	},
	config = function()
		require("scope").setup({})
		vim.keymap.set(
			{ "n" },
			"<leader>tt",
			"<cmd>ScopeMoveBuf<cr>",
			{ desc = "移动buferr到别的tabs", noremap = true, silent = true }
		)
	end,
}
