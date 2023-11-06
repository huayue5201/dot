-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate",
	event = "VeryLazy", -- keep for lazy loading
	config = function()
		require("illuminate").configure({
			providers = {
				"lsp",
				"treesitter",
				"regex",
			},
		})
	end,
}
