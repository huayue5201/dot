-- https://github.com/rachartier/tiny-cmdline.nvim

return {
	"rachartier/tiny-cmdline.nvim",
	config = function()
		vim.o.cmdheight = 0
		require("tiny-cmdline").setup({
			-- Window position ("N%" = fraction of available space, integer = absolute columns/rows)
			position = {
				x = "50%", -- horizontal: "0%" = left, "50%" = center, "100%" = right
				y = "15%", -- vertical:   "0%" = top,  "50%" = center, "100%" = bottom
			},
			-- Dynamic popup title (rendered on the floating border)
			-- Disabled by default; set enabled = true to opt in
			-- Has no effect when border = "none" or when the cmdline is rendered via native_types
			title = {
				enabled = true,
				pos = "center", -- "left" | "center" | "right"
			},

			on_reposition = require("tiny-cmdline").adapters.blink,
		})
	end,
}
