-- https://github.com/sindrets/diffview.nvim?tab=readme-ov-file

return {
	"sindrets/diffview.nvim",
	keys = {
		{ "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "打开diffview" },
		{ "<leader>gf", "<cmd>DiffviewToggleFiles<cr>", desc = "打开difffiles" },
	},
}
