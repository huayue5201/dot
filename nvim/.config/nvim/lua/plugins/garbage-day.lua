-- https://github.com/Zeioth/garbage-day.nvim

return {
	"zeioth/garbage-day.nvim",
	event = "VeryLazy",
	config = function()
		require("garbage-day").setup({
			-- 基础配置
			aggressive_mode = false,
			grace_period = 60 * 15,
			wakeup_delay = 100,

			-- 排除不需要停止的 LSP
			excluded_lsp_clients = {
				"copilot",
				"lua_ls",
				"rust-analyzer",
			},

			-- 调试选项
			notifications = true,

			-- 高级选项
			retries = 3,
			timeout = 1000,
		})
	end,
}
