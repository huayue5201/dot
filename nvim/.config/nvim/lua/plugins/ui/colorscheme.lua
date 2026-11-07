-- https://github.com/bytebeast/kissaten.nvim
-- https://github.com/huayue5201/night-owl.nvim （上游 oxfist/night-owl.nvim 的本地 fork）
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "bytebeast/kissaten.nvim",
	-- "folke/tokyonight.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "ShiraiEd/Wolf359_nvim_rust_theme",
	dir = "~/neovim-plugins/night-owl.nvim",
	priority = 1000,
	opts = {
		-- morning(浅) | afternoon | evening | midnight
		-- style = "morning",
		-- light_style = "evening",
		-- transparent = false,
		-- terminal_colors = true,
		-- dim_inactive = false,
		-- contrast = "normal",
		-- subtle_comments = false,
		-- styles = {
		-- 	comments = { italic = true },
		-- 	keywords = { italic = true },
		-- 	sidebars = "dark",
		-- 	floats = "dark",
		-- },
		-- These are the default settings
		bold = true,
		italics = true,
		underline = true,
		undercurl = true,
		transparent_background = false,
		-- 非当前窗口变暗，聚焦窗口更醒目
		dim_inactive = true,
	},
	config = function(_, opts)
		-- require("kissaten").setup(opts)
		-- "kissaten" 跟随 vim.o.background；也可钉死某个风格，如 kissaten-midnight
		-- vim.cmd.colorscheme("kissaten")

		-- vim.cmd([[colorscheme tokyonight]])
		require("night-owl").setup(opts)
		vim.cmd.colorscheme("night-owl")
	end,
}
