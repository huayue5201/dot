-- https://github.com/folke/which-key.nvim

vim.g.later(function()
	vim.g.add({ source = "folke/which-key.nvim" })

	require("which-key").setup({
		preset = "helix",
	})

	vim.keymap.set("n", "<leader>?", function()
		require("which-key").show({ global = false })
	end, { desc = "Buffer Local Keymaps (which-key)" })
end)
