-- https://github.com/benlubas/molten-nvim?tab=readme-ov-file

return {
	"benlubas/molten-nvim",
	build = ":UpdateRemotePlugins",
	ft = { "python" },
	dependencies = { "3rd/image.nvim" },
	init = function()
		-- these are examples, not defaults. Please see the readme
		vim.g.molten_image_provider = "image.nvim"
		vim.g.molten_output_win_max_height = 20
	end,
	config = function()
		vim.keymap.set("n", "<leader>mi", ":MoltenInit<CR>", { silent = true, desc = "Initialize the plugin" })
		vim.keymap.set(
			"n",
			"<leader>me",
			":MoltenEvaluateOperator<CR>",
			{ silent = true, desc = "run operator selection" }
		)
		vim.keymap.set("n", "<leader>ml", ":MoltenEvaluateLine<CR>", { silent = true, desc = "evaluate line" })
		vim.keymap.set("n", "<leader>mt", ":MoltenReevaluateCell<CR>", { silent = true, desc = "re-evaluate cell" })
		vim.keymap.set(
			"v",
			"<leader>mv",
			":<C-u>MoltenEvaluateVisual<CR>gv",
			{ silent = true, desc = "evaluate visual selection" }
		)
		vim.keymap.set("n", "<leader>md", ":MoltenDelete<CR>", { silent = true, desc = "molten delete cell" })
		vim.keymap.set("n", "<leader>mh", ":MoltenHideOutput<CR>", { silent = true, desc = "hide output" })
		vim.keymap.set(
			"n",
			"<leader>ms",
			":noautocmd MoltenEnterOutput<CR>",
			{ silent = true, desc = "show/enter output" }
		)
	end,
}
