-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim

return {
	"oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "serhez/teide.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("night-owl").setup()
		vim.cmd.colorscheme("night-owl")

		-- require("nightfox").setup({
		-- 	options = {
		-- 		-- 是否使非焦点窗口使用不同的背景颜色，增强视觉分隔
		-- 		dim_inactive = true,
		-- 	},
		-- })
		-- vim.cmd("colorscheme Carbonfox")

		-- vim.cmd([[colorscheme teide]])
	end,
}
