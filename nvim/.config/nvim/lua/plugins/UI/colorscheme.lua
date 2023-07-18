-- https://github.com/projekt0n/github-nvim-theme
-- 主题配置

return {
	"projekt0n/github-nvim-theme",
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	priority = 1000, -- make sure to load this before all the other start plugins
	config = function()
		require("github-theme").setup({
			-- ...
		})

		vim.cmd("colorscheme github_dark")
	end,
}
