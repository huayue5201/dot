-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate",
	event = { "BufReadPost" },
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
