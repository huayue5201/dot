-- https://github.com/williamboman/mason.nvim

vim.g.later(function()
	vim.g.add({ source = "williamboman/mason.nvim" })

	require("mason").setup({
		ui = {
			border = "rounded",
		},
	})
end)
