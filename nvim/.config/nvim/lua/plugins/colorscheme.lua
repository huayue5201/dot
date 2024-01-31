-- https://github.com/rebelot/kanagawa.nvim
-- 主题配置

return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	lazy = false, -- make sure we load this during startup if it is your main colorscheme
	config = function()
		require("catppuccin").setup({
			flavour = "mocha", -- latte, frappe, macchiato, mocha
			integrations = {
				cmp = true,
				gitsigns = true,
				treesitter = true,
				aerial = true,
				fidget = true,
				harpoon = true,
				mason = true,
				lsp_trouble = true,
				which_key = true,
				-- dropbar = {
				-- 	enabled = true,
				-- 	color_mode = true, -- enable color for kind's texts, not just kind's icons
				-- },
			},
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
