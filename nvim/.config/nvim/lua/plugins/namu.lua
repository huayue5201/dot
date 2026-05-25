-- https://github.com/bassamsdata/namu.nvim

return {
	"bassamsdata/namu.nvim",
	event = "VeryLazy",
	config = function()
		require("namu").setup({})
		-- === Suggested Keymaps: ===
		vim.keymap.set("n", "<leader>ssb", ":Namu symbols<cr>", {
			desc = "Jump to LSP symbol",
			silent = true,
		})
		vim.keymap.set("n", "<leader>ssw", ":Namu workspace<cr>", {
			desc = "LSP Symbols - Workspace",
			silent = true,
		})
		vim.keymap.set("n", "<leader>sas", ":Namu watchtower<cr>", {
			desc = "LSP Symbols - Watchtower",
			silent = true,
		})
		vim.keymap.set("n", "<leader>sd", ":Namu diagnostics<cr>", {
			desc = "LSP Symbols - Diagnostics",
			silent = true,
		})
		vim.keymap.set("n", "<leader>sci", ":Namu call in<cr>", {
			desc = "LSP Symbols - Call in",
			silent = true,
		})
		vim.keymap.set("n", "<leader>sco", ":Namu call out<cr>", {
			desc = "LSP Symbols - Call out",
			silent = true,
		})
		vim.keymap.set("n", "<leader>scb", ":Namu call both<cr>", {
			desc = "LSP Symbols - Call both",
			silent = true,
		})
	end,
}
