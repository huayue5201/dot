-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>tl", "<cmd>AerialToggle!<CR>", desc = "大纲" },
	},
	opts = {
		backends = { "lsp", "treesitter", "markdown", "man" },
		on_attach = function(bufnr)
			-- Jump forwards/backwards with '{' and '}'
			vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
			vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
		end,
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
