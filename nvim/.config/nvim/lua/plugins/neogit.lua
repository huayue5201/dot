-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	keys = {
		{ "<leader>oi", "<cmd>Neogit<cr>", desc = "git管理" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"sindrets/diffview.nvim",
	},
	config = true,
}
