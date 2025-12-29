-- https://github.com/rachartier/tiny-inline-diagnostic.nvim

return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	priority = 1000,
	config = function()
		require("tiny-inline-diagnostic").setup()
		vim.diagnostic.open_float = require("tiny-inline-diagnostic.override").open_float
		vim.keymap.set("n", "<leader>rD", "<cmd>TinyInlineDiag toggle<cr>", { desc = "Toggle diagnostics" })
	end,
}
