-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	event = "VeryLazy",
	keys = { "<leader>tp", "<cmd>ScopeMoveBuf<cr>", desc = "移动buferr到别的tabs" },
	config = function()
		require("scope").setup({})
	end,
}
