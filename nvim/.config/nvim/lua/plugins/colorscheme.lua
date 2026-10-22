-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "oxfist/night-owl.nvim",
	"folke/tokyonight.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "ShiraiEd/Wolf359_nvim_rust_theme",
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")

		vim.cmd([[colorscheme tokyonight]])

		-- require("nightfox").setup({
		-- 	options = {
		-- 		-- 是否使非焦点窗口使用不同的背景颜色，增强视觉分隔
		-- 		dim_inactive = true,
		-- 	},
		-- })
		-- vim.cmd("colorscheme Carbonfox")

		-- vim.cmd("colorscheme wolf359")
	end,
}
