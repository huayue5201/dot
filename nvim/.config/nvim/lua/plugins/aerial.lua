-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>oa", "<cmd>AerialToggle<CR>", desc = "大纲/侧边栏" },
		{ "<leader>ov", "<cmd>AerialNavToggle<CR>", desc = "大纲/浮窗" },
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("aerial").setup({
			on_attach = function(bufnr)
				-- Jump forwards/backwards with '{' and '}'
				vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
				vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
			end,
			-- Priority list of preferred backends for aerial.
			-- This can be a filetype map (see :help aerial-filetype-map)
			backends = { "treesitter", "lsp", "markdown", "man" },

			layout = {
				-- aerial边栏大小
				max_width = { 40, 0.2 },
				width = nil,
				min_width = 35,

				-- 窗口位置
				-- Enum: prefer_right, prefer_left, right, left, float
				default_direction = "prefer_right",
			},
			-- Highlight the symbol in the source buffer when cursor is in the aerial win
			highlight_on_hover = true,
			-- 层级线条支持
			show_guides = true,
			-- Customize the characters used when show_guides = true
			guides = {
				-- When the child item has a sibling below it
				mid_item = "├─",
				-- When the child item is the last in the list
				last_item = "└─",
				-- When there are nested child guides to the right
				nested_top = "│ ",
				-- Raw indentation
				whitespace = "  ",
			},
			nav = {
				keymaps = {
					["q"] = "actions.close",
					["<C-c>"] = "actions.close",
				},
			},
		})
	end,
}
