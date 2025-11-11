-- https://github.com/andrewferrier/debugprint.nvim

return {
	"andrewferrier/debugprint.nvim",
	lazy = false,
	version = "*", -- Remove if you DON'T want to use the stable version
	config = function()
		vim.api.nvim_set_hl(0, "DebugPrintLine", { fg = "#ff0000", bg = "#333333" })
		require("debugprint").setup({
			highlight_lines = true,
		})
		vim.keymap.set("n", "g?r", "<cmd>DeleteDebugPrints<cr>", { desc = "删除所有调试语句" })
		vim.keymap.set("n", "g?l", "<cmd>DebugPrintQFList<cr>", { desc = "查看所有调试语句" })
	end,
}
