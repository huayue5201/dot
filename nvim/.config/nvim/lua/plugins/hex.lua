-- https://github.com/RaafatTurki/hex.nvim

return {
	"RaafatTurki/hex.nvim",
	keys = {
		{ "<leader>hx" },
	},
	config = function()
		vim.keymap.set(
			"n",
			"<localleader>hx",
			"<cmd>lua require 'hex'.toggle() <CR>",
			{ silent = true,   desc = "" }
		)
	end,
}
