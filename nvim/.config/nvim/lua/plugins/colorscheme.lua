-- https://github.com/rebelot/kanagawa.nvim
-- 主题配置

return {
	"Mofiqul/dracula.nvim",
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	priority = 1000, -- make sure to load this before all the other start plugins
	config = function()
		vim.cmd([[colorscheme dracula]])
	end,
}
