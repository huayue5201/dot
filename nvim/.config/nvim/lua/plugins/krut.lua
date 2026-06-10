-- https://github.com/alexpasmantier/krust.nvim

return {
	"alexpasmantier/krust.nvim",
	ft = "rust",
	config = function()
		require("krust").setup({
			keymap = "grk", -- Set a keymap for Rust buffers (default: false)
			float_win = {
				border = "rounded", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
				auto_focus = false, -- Auto-focus float (default: false)
			},
		})
	end,
}
