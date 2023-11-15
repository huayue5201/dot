-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	event = "BufNewFile", -- keep for lazy loading
	keys = {
		{ "<leader>gi", "<cmd>Neogit<cr>", desc = "git管理" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
	},
	config = true,
}
