-- https://github.com/rachartier/tiny-cmdline.nvim

return {
	"rachartier/tiny-cmdline.nvim",
	init = function()
		-- vim.api.nvim_set_hl(0, "TinyCmdlineBorder", { fg = "#0000FF" })
		-- vim.api.nvim_set_hl(0, "TinyCmdlineNormal", { bg = "#00FF00" })
		vim.o.cmdheight = 0
		vim.g.tiny_cmdline = {
			width = { value = "70%" },
		}
	end,
}
