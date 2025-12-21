-- https://github.com/folke/persistence.nvim

return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {
		-- session 存储路径（每项目自动隔离）
		-- dir = vim.fn.stdpath("state") .. "/sessions/",

		-- 保存哪些东西
		-- options = {
		--   "buffers",
		--   "curdir",
		--   "tabpages",
		--   "winsize",
		-- 如果你需要 folds / help / local options，也可以加：
		-- "help",
		-- "options",
		-- "folds",
		-- },
	},

	keys = {
		-- 恢复上次 session
		{
			"<leader>rs",
			function()
				require("persistence").load()
			end,
			desc = "persistence: Load session for current dir",
		},

		-- 恢复上一次退出的 session
		{
			"<leader>rt",
			function()
				require("persistence").load({ last = true })
			end,
			desc = "persistence: Restore last session",
		},

		-- 不加载 session 启动
		{
			"<leader>rd",
			function()
				require("persistence").stop()
			end,
			desc = "persistence: Stop session save",
		},
	},
}
