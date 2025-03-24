-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim

return {
	-- "oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	"tomasiser/vim-code-dark",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme nordfox")
		vim.cmd.colorscheme("codedark")
	end,
}
