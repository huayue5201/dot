-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	"uhs-robert/oasis.nvim",
	-- "folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme Carbonfox")
		require("oasis").setup() -- (see Configuration below for all customization options)
		vim.cmd.colorscheme("oasis") -- After setup, apply theme (or a any style like "oasis-night")
		-- vim.cmd.colorscheme("vscode")
		-- vim.cmd([[colorscheme tokyonight-night]])
	end,
}
