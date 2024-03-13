-- https://github.com/EdenEast/nightfox.nvim
-- 主题配置

return {
	-- "EdenEast/nightfox.nvim",
	"lunarvim/synthwave84.nvim",
	priority = 1000,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	config = function()
		vim.cmd("colorscheme synthwave84")
		-- vim.cmd("colorscheme Nightfox")
	end,
}
