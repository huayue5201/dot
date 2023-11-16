-- https://github.com/olimorris/persisted.nvim

return {
	"olimorris/persisted.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim",
	},
	keys = {
		{ "<leader>ws", "<cmd>SessionSave<cr>", desc = "保存会话" },
		{ "<leader>wr", "<cmd>SessionLoad<cr>", desc = "恢复会话" },
		{ "<leader>wo", "<cmd>Telescope persisted<cr>", desc = "会话管理" },
	},
	config = true,
}
