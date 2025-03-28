-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	cmd = "Neogit",
	keys = { "<leader>go", desc = "Neogit" },
	dependencies = {
		"nvim-lua/plenary.nvim", -- required
		"sindrets/diffview.nvim", -- optional - Diff integration
	},
	config = function()
		require("neogit").setup({})
		vim.keymap.set("n", "<leader>go", "<cmd>Neogit<cr>", { silent = true, desc = "Neogit" })
	end,
}
