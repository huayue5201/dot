-- https://github.com/esmuellert/vscode-diff.nvim

return {
	"esmuellert/vscode-diff.nvim",
	event = "VeryLazy",
	dependencies = { "MunifTanjim/nui.nvim" },
	config = function()
		require("vscode-diff").setup({
			highlights = {
				-- Line-level: accepts highlight group names or hex colors (e.g., "#2ea043")
				line_insert = "DiffAdd", -- Line-level insertions
				line_delete = "DiffDelete", -- Line-level deletions

				-- Character-level: accepts highlight group names or hex colors
				-- If specified, these override char_brightness calculation
				char_insert = nil, -- Character-level insertions (nil = auto-derive)
				char_delete = nil, -- Character-level deletions (nil = auto-derive)

				-- Brightness multiplier (only used when char_insert/char_delete are nil)
				-- nil = auto-detect based on background (1.4 for dark, 0.92 for light)
				char_brightness = nil, -- Auto-adjust based on your colorscheme
			},

			-- Diff view behavior
			diff = {
				disable_inlay_hints = true, -- Disable inlay hints in diff windows for cleaner view
				max_computation_time_ms = 5000, -- Maximum time for diff computation (VSCode default)
			},
			-- Explorer panel configuration
			explorer = {
				position = "bottom", -- "left" or "bottom"
				width = 40, -- Width when position is "left" (columns)
				height = 15, -- Height when position is "bottom" (lines)
			},
			-- Keymaps in diff view
			keymaps = {
				view = {
					quit = "q", -- Close diff tab
					toggle_explorer = "<leader>b", -- Toggle explorer visibility (explorer mode only)
					next_hunk = "]c", -- Jump to next change
					prev_hunk = "[c", -- Jump to previous change
					next_file = "]f", -- Next file in explorer mode
					prev_file = "[f", -- Previous file in explorer mode
				},
				explorer = {
					select = "<CR>", -- Open diff for selected file
					hover = "K", -- Show file diff preview
					refresh = "R", -- Refresh git status
				},
			},
		})
		vim.keymap.set("n", "<leader>gf", "<cmd>CodeDiff<cr>", { desc = "vscode-diff: Diff" })
	end,
}
