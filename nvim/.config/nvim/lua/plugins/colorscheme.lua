-- https://github.com/rebelot/kanagawa.nvim
-- 主题配置

return {
	"rebelot/kanagawa.nvim",
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	priority = 1000, -- make sure to load this before all the other start plugins
	config = function()
		require("kanagawa").setup({
			compile = true,
			colors = {
				theme = {
					all = {
						ui = {
							bg_gutter = "none",
						},
					},
				},
			},
		})
		vim.cmd([[colorscheme kanagawa]])
	end,
}
