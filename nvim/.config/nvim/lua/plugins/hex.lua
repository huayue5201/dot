-- https://github.com/RaafatTurki/hex.nvim

return {
	"RaafatTurki/hex.nvim",
	keys = {
		{ "<localleader>h" },
	},
	config = function()
		vim.keymap.set("n", "<localleader>h", "<cmd>lua require 'hex'.toggle() <CR>", { silent = true, desc = "" })
	end,
}
