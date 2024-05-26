-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	dependencies = "nvim-telescope/telescope.nvim",
	keys = { "<leader>fb", mode = "n", "<cmd>Telescope scope buffers<cr>", desc = "buffer检索" },
	config = function()
		require("scope").setup({})
		require("telescope").load_extension("scope")
	end,
}
