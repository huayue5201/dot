-- https://github.com/error311/wayfinder.nvim

return {
	"error311/wayfinder.nvim",
	config = function()
		require("wayfinder").setup({})

		vim.keymap.set("n", "grw", "<Plug>(WayfinderOpen)", {
			desc = "Wayfinder",
		})
	end,
}
