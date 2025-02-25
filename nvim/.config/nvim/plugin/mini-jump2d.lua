-- https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-jump2d.md

vim.g.later(function()
	vim.g.add({ source = "echasnovski/mini.jump2d" })

	require("mini.jump2d").setup({
		mappings = {
			start_jumping = "<leader>s",
		},
	})
end)
