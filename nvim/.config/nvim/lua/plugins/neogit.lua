-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	keys = {
		{ "<leader>gi", "<cmd>Neogit<cr>", desc = "git管理" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"sindrets/diffview.nvim",
		"ibhagwan/fzf-lua",
	},
	config = true,
}
