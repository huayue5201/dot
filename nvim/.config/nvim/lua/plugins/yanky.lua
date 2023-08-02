-- https://github.com/gbprod/yanky.nvim

return {
	"gbprod/yanky.nvim",
	dependencies = "kkharji/sqlite.lua",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("yanky").setup({
			ring = {
				history_length = 100,
				storage = "sqlite",
				sync_with_numbered_registers = true,
				cancel_event = "update",
				ignore_registers = { "_" },
			},
			system_clipboard = {
				sync_with_ring = true,
			},
		})
		vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)")
		vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)")
		vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)")
		vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)")
		vim.keymap.set("n", "<c-n>", "<Plug>(YankyCycleForward)")
		vim.keymap.set("n", "<c-p>", "<Plug>(YankyCycleBackward)")
	end,
}
