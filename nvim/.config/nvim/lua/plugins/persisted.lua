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
	config = function()
		require("persisted").setup({
			-- 开启git支持
			use_git_branch = true,
			-- 自动保存
			autosave = false,
		})
	end,
}
