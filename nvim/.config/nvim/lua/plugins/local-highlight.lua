-- https://github.com/tzachar/local-highlight.nvim

return {
	"tzachar/local-highlight.nvim",
	event = "VeryLazy", -- keep for lazy loading
	config = function()
		require("local-highlight").setup()
	end,
}
