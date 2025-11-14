-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "oxfist/night-owl.nvim",
	"EdenEast/nightfox.nvim",
	-- "folke/tokyonight.nvim",
	dependencies = "rktjmp/lush.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		vim.cmd("colorscheme Carbonfox")

		-- 加载主题，但不影响 devicon 的颜色
		-- vim.cmd.colorscheme("vscode")
		-- vim.cmd([[colorscheme tokyonight-night]])
	end,
}
