-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	"oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("night-owl").setup()
		vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme Carbonfox")
		-- vim.cmd([[colorscheme tokyonight-night]])
	end,
}
