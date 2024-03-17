-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/askfiy/visual_studio_code
-- 主题配置

return {
	-- "EdenEast/nightfox.nvim",
	"askfiy/visual_studio_code",
	priority = 1000,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	config = function()
		-- vim.cmd("colorscheme Duskfox")
		vim.cmd([[colorscheme visual_studio_code]])
	end,
}
