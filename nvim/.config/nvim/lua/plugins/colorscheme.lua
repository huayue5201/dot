-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/oxfist/night-owl.nvim

return {
	"EdenEast/nightfox.nvim",
	-- "oxfist/night-owl.nvim",
	-- "folke/tokyonight.nvim",
	-- "Mofiqul/dracula.nvim",
	priority = 1000,
	-- event = "VeryLazy",
	-- lazy = true,
	lazy = false,
	config = function()
		vim.cmd("colorscheme Duskfox")
		-- vim.cmd("colorscheme Dayfox")
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd.colorscheme("tokyonight-night")
		-- vim.cmd.colorscheme("dracula")
	end,
}
