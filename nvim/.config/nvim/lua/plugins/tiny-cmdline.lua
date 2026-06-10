-- https://github.com/rachartier/tiny-cmdline.nvim

return {
	"rachartier/tiny-cmdline.nvim",
	init = function()
		vim.api.nvim_set_hl(0, "TinyCmdlineBorder", { fg = "#0000FF" })
		vim.api.nvim_set_hl(0, "TinyCmdlineNormal", { bg = "#00FF00" })
		vim.o.cmdheight = 0
		vim.g.tiny_cmdline = {
			width = { value = "70%" },
			position = {
				x = "50%", -- horizontal: "0%" = left, "50%" = center, "100%" = right
				y = "15%", -- vertical:   "0%" = top,  "50%" = center, "100%" = bottom
			},
			title = {
				enabled = true,
				pos = "center", -- "left" | "center" | "right"
			},
			on_reposition = require("tiny-cmdline").adapters.blink,
		}
	end,
}
