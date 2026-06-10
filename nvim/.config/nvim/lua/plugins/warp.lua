-- https://github.com/nolleh/warp.nvim

return {
	"nolleh/warp.nvim",
	event = "VeryLazy",
	config = function()
		require("warp").setup({
			default_keymap = "<leader>jf", -- or false to disable
		})
	end,
}
