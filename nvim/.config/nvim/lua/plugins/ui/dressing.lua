-- https://github.com/stevearc/dressing.nvim

return {
	"stevearc/dressing.nvim",
	event = "VeryLazy", -- keep for lazy loading
	opts = {
		select = {
			-- Priority list of preferred vim.select implementations
			backend = { "builtin" },
		},
	},
}
