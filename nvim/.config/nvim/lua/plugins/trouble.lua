-- https://github.com/folke/trouble.nvim

return {
	"folke/trouble.nvim",
	event = "VeryLazy",
	cmd = "Trouble",
	config = function()
		require("trouble").setup({
			modes = {
				test = {
					mode = "diagnostics",
					preview = {
						type = "split",
						relative = "win",
						position = "right",
						size = 0.3,
					},
				},
			},
		})

		-- 设置快捷键
		local keymap = vim.keymap.set
		local opts = { noremap = true, silent = true }

		keymap(
			"n",
			"<leader>xx",
			"<cmd>Trouble diagnostics toggle<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle diagnostics (all buffers)" })
		)
		keymap(
			"n",
			"<leader>xX",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle diagnostics (current buffer)" })
		)
		keymap(
			"n",
			"<leader>xs",
			"<cmd>Trouble symbols toggle focus=false win.size=48<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle symbols (document)" })
		)
		keymap(
			"n",
			"<leader>xS",
			"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle LSP references" })
		)
		keymap(
			"n",
			"<leader>xi",
			"<cmd>Trouble lsp_incoming_calls<cr>",
			vim.tbl_extend("force", opts, { desc = "Show LSP incoming calls" })
		)
		keymap(
			"n",
			"<leader>xo",
			"<cmd>Trouble lsp_outgoing_calls<cr>",
			vim.tbl_extend("force", opts, { desc = "Show LSP outgoing calls" })
		)
		keymap(
			"n",
			"<leader>xL",
			"<cmd>Trouble loclist toggle<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle location list" })
		)
		keymap(
			"n",
			"<leader>xQ",
			"<cmd>Trouble qflist toggle<cr>",
			vim.tbl_extend("force", opts, { desc = "Toggle quickfix list" })
		)
	end,
}
