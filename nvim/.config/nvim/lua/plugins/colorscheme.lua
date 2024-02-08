-- https://github.com/rebelot/kanagawa.nvim
-- 主题配置

return {
	"olimorris/onedarkpro.nvim",
	priority = 1000,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	config = function()
		require("onedarkpro").setup({
			options = {
				highlight_inactive_windows = true,
			},
		})
		vim.cmd("colorscheme onedark")
	end,
}
