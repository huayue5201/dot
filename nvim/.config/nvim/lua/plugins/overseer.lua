-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	keys = { "<leader>ru", "<leader>rt" },
	config = function()
		require("overseer").setup()
		vim.keymap.set("n", "<leader>rt", "<cmd>OverseerToggle<cr>")
		vim.keymap.set("n", "<leader>ru", "<cmd>OverseerRun<cr>")
	end,
}
