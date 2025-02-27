-- https://github.com/RaafatTurki/hex.nvim

vim.g.later(function()
	vim.g.add({ source = "RaafatTurki/hex.nvim" })

	vim.keymap.set(
		"n",
		"<localleader>hx",
		"<cmd>lua require 'hex'.toggle() <CR>",
		{ silent = true, noremap = true, desc = "" }
	)
end)
