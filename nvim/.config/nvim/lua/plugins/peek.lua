-- https://github.com/toppair/peek.nvim

return {
	"toppair/peek.nvim",
	event = { "VeryLazy" },
	build = "deno task --quiet build:fast",
	config = function()
		require("peek").setup({
			auto_load = true, -- 是否在进入另一个 Markdown 缓冲区时自动加载预览
			close_on_bdelete = true, -- 在删除缓冲区时关闭预览窗口
			syntax = true, -- 启用语法高亮（会影响性能）
			theme = "dark", -- 'dark'（深色主题）或 'light'（浅色主题）
			update_on_change = true, -- 是否在文件变更时更新预览
			app = "webview", -- 'webview'（网页视图）、'browser'（浏览器）、
			-- 字符串或字符串表（具体说明见下文）
			filetype = { "markdown" }, -- 要识别为 Markdown 的文件类型列表
			-- 当 update_on_change 为 true 时，以下配置生效
			throttle_at = 200000, -- 当文件超过此字节数时开始节流控制
			-- （200000 字节 ≈ 200KB）
			throttle_time = "auto", -- 在开始新渲染之前必须经过的最短时间间隔
			-- （毫秒），'auto' 表示自动调整
		})
		vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
		vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
	end,
}
