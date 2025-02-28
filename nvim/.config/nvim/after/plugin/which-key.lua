vim.g.later(function()
	vim.g.add({ source = "folke/which-key.nvim" })

	require("which-key").setup({
		preset = "helix",
	})
end)
