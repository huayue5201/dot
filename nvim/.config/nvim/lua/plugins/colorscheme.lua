-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim

return {
	-- "oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "tomasiser/vim-code-dark",
	-- "shaunsingh/nord.nvim",
	"folke/tokyonight.nvim",
	-- "loctvl842/monokai-pro.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme nordfox")
		-- vim.cmd.colorscheme("codedark")
		-- vim.cmd([[colorscheme nord]])
		vim.cmd([[colorscheme tokyonight]])
		-- require("monokai-pro").setup({
		-- ... your config
		-- background_clear = { "float_win" },
		-- })
		-- lua
		-- vim.cmd([[colorscheme monokai-pro]])
	end,
}
