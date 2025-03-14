-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim

return {
	-- "oxfist/night-owl.nvim",
	"EdenEast/nightfox.nvim",
	-- "RRethy/base16-nvim",
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		vim.cmd("colorscheme Duskfox")
		-- vim.cmd("colorscheme base16-gruvbox-dark-soft")
		-- require("base16-colorscheme").setup({
		-- 	base00 = "#16161D",
		-- 	base01 = "#2c313c",
		-- 	base02 = "#3e4451",
		-- 	base03 = "#6c7891",
		-- 	base04 = "#565c64",
		-- 	base05 = "#abb2bf",
		-- 	base06 = "#9a9bb3",
		-- 	base07 = "#c5c8e6",
		-- 	base08 = "#e06c75",
		-- 	base09 = "#d19a66",
		-- 	base0A = "#e5c07b",
		-- 	base0B = "#98c379",
		-- 	base0C = "#56b6c2",
		-- 	base0D = "#0184bc",
		-- 	base0E = "#c678dd",
		-- 	base0F = "#a06949",
		-- })
	end,
}
