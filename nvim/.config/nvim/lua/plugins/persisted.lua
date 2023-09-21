-- https://github.com/olimorris/persisted.nvim

return {
	"olimorris/persisted.nvim",
	keys = {
		{ "<leader>wi", "<cmd>SessionSave<cr>", desc = "保存会话" },
		{ "<leader>wo", "<cmd>SessionLoad<cr>", desc = "恢复会话" },
	},
	opts = {
      -- git
		use_git_branch = true,
		-- 自动保存会话
		autosave = false,
	},
}
