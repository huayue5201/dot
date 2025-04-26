-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	"rebelot/kanagawa.nvim",
	-- "tomasiser/vim-code-dark",
	-- "shaunsingh/nord.nvim",
	-- "folke/tokyonight.nvim",
	-- "loctvl842/monokai-pro.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme nordfox")
		vim.cmd("colorscheme kanagawa")
		-- vim.cmd.colorscheme("codedark")
		-- vim.cmd([[colorscheme nord]])
		-- vim.cmd([[colorscheme tokyonight-night]])
		-- require("monokai-pro").setup({
		-- 	background_clear = { "float_win" },
		-- })
		-- vim.cmd([[colorscheme monokai-pro]])
		require("kanagawa").setup({
			overrides = function(colors)
				local theme = colors.theme
				return {
					NormalFloat = { bg = "none" },
					FloatBorder = { bg = "none" },
					FloatTitle = { bg = "none" },

					-- Save an hlgroup with dark background and dimmed foreground
					-- so that you can use it where your still want darker windows.
					-- E.g.: autocmd TermOpen * setlocal winhighlight=Normal:NormalDark
					NormalDark = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m3 },

					-- Popular plugins that open floats will link to NormalFloat by default;
					-- set their background accordingly if you wish to keep them dark and borderless
					LazyNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
					MasonNormal = { bg = theme.ui.bg_m3, fg = theme.ui.fg_dim },
				}
			end,
		})
	end,
}
