-- https://github.com/EdenEast/nightfox.nvim
-- 主题配置

return {
	"EdenEast/nightfox.nvim",
	priority = 1000,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	config = function()
		vim.cmd("colorscheme duskfox")
	end,
}
