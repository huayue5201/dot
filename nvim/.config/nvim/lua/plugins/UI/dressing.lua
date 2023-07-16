-- https://github.com/stevearc/dressing.nvim

return {
	"stevearc/dressing.nvim",
	event = "VeryLazy", -- keep for lazy loading
	lazy = true,
	opts = {
		select = {
			-- Set to false to disable the vim.ui.select implementation
			enabled = true,
		},
	},
}
