-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	cmd = "Neogit",
	keys = {
		{ "<leader>go", desc = "Neogit" },
		{ "<leader>gc", desc = "Neogit commit" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim", -- required
		-- https://github.com/sindrets/diffview.nvim
		"sindrets/diffview.nvim", -- optional - Diff integration
	},
	config = function()
		require("neogit").setup({})
		vim.keymap.set("n", "<leader>go", "<cmd>Neogit<cr>", { silent = true, desc = "Neogit" })
		vim.keymap.set("n", "<leader>gc", "<cmd>Neogit commit<cr>", { silent = true, desc = "Neogit commit" })
	end,
}
