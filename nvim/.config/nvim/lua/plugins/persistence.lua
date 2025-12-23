-- https://github.com/folke/persistence.nvim

return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	config = function()
		require("persistence").setup()
	end,
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
