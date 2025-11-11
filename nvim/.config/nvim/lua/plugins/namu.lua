-- https://github.com/bassamsdata/namu.nvim/tree/main

return {
	"bassamsdata/namu.nvim",
	opts = {
		global = {},
		namu_symbols = { -- Specific Module options
			options = {},
		},
	},
	config = function()
		-- === Suggested Keymaps: ===
		vim.keymap.set("n", "<leader>ls", ":Namu symbols<cr>", {
			desc = "Jump to LSP symbol",
			silent = true,
		})
		vim.keymap.set("n", "<leader>lS", ":Namu workspace<cr>", {
			desc = "LSP Symbols - Workspace",
			silent = true,
		})
	end,
}
