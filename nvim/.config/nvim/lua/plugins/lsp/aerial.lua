-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>tl", "<cmd>AerialToggle!<CR>", desc = "大纲" },
	},
	opts = {
		backends = { "lsp", "treesitter", "markdown", "man" },
		-- 结构线
		show_guides = true,
		layout = {
			-- 边栏宽度
			min_width = 30,
		},
	},
	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
}
