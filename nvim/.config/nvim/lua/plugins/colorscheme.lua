-- https://github.com/bytebeast/kissaten.nvim
-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	"bytebeast/kissaten.nvim",
	-- "folke/tokyonight.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "ShiraiEd/Wolf359_nvim_rust_theme",
	priority = 1000,
	opts = {
		-- morning(浅) | afternoon | evening | midnight
		style = "midnight",
		light_style = "morning",
		transparent = false,
		terminal_colors = true,
		dim_inactive = false,
		contrast = "normal",
		subtle_comments = false,
		styles = {
			comments = { italic = true },
			keywords = { italic = true },
			sidebars = "dark",
			floats = "dark",
		},
	},
	config = function(_, opts)
		require("kissaten").setup(opts)
		-- "kissaten" 跟随 vim.o.background；也可钉死某个风格，如 kissaten-midnight
		vim.cmd.colorscheme("kissaten")

		-- vim.cmd([[colorscheme tokyonight]])
	end,
}
