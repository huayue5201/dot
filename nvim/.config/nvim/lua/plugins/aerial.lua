-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>ea", desc = "符号树" },
		{ "<leader>ev", desc = "符号树浮窗" },
	},
	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("aerial").setup({
			-- optionally use on_attach to set keymaps when aerial has attached to a buffer
			on_attach = function(bufnr)
				-- Jump forwards/backwards with '{' and '}'
				vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
				vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
			end,
			-- 控制aerial窗口的宽度和布局选项
			-- 包括最大宽度、宽度、最小宽度、默认打开方向和位置
			layout = {
				max_width = { 40, 0.2 },
				width = nil,
				min_width = 30,
				default_direction = "prefer_left",
				placement = "window",
			},
			highlight_on_hover = true,
			autojump = true,
			-- 折叠
			manage_folds = true,
			show_guides = true,
		})
		-- You probably also want to set a keymap to toggle aerial
		vim.keymap.set("n", "<leader>ea", "<cmd>AerialToggle!<CR>")
		vim.keymap.set("n", "<leader>ev", "<cmd>AerialNavToggl<CR>")
	end,
}
