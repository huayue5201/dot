-- https://github.com/rachartier/tiny-inline-diagnostic.nvim

return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	priority = 1000,
	config = function()
		require("tiny-inline-diagnostic").setup({
			preset = "modern",
		})
		vim.diagnostic.open_float = require("tiny-inline-diagnostic.override").open_float
		vim.keymap.set("n", "<s-a-d>", "<cmd>TinyInlineDiag toggle<cr>", { desc = "LSP: Toggle diagnostics" })
	end,
}
