-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	dependencies = "nvim-telescope/telescope.nvim",
	keys = {
		"<leader>ta",
		"<leader>tt",
		desc = "移动buferr到别的tabs",
		{ "<leader>fb", desc = "buffer检索" },
	},
	config = function()
		require("scope").setup({})
		require("telescope").load_extension("scope")
		keymap({ "n" }, "<leader>tt", "<cmd>ScopeMoveBuf<cr>", { desc = "移动buferr到别的tabs" })
		keymap("n", "<space>fb", "<cmd>Telescope scope buffers<cr>", { desc = "buffer检索" })
	end,
}
