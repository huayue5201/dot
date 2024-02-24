-- https://github.com/sindrets/diffview.nvim

return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory" },
	keys = {
		{ "<leader>od", "<cmd>DiffviewOpen<cr>", desc = "Diff" },
	},
}
