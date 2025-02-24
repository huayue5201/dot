-- https://github.com/akinsho/toggleterm.nvim

vim.g.later(function()
	vim.g.add({ source = "akinsho/toggleterm.nvim" })

	require("toggleterm").setup({
		size = 25,
		open_mapping = [[<c-\>]],
	})

	vim.keymap.set({ "t", "n" }, "<leader>\\", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle terminal" })
end)
