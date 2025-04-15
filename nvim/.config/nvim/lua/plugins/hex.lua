-- https://github.com/RaafatTurki/hex.nvim

return {
	"RaafatTurki/hex.nvim",
	keys = {
		{ "<localleader>h", desc = "进制转换" },
	},
	config = function()
		vim.keymap.set(
			"n",
			"<localleader>h",
			"<cmd>lua require 'hex'.toggle()<CR>",
			{ silent = true, desc = "进制转换" }
		)
	end,
}
