-- Yanky.nvim 插件配置
-- 官方文档: https://github.com/gbprod/yanky.nvim#ringhistory_length

return {
	"gbprod/yanky.nvim", -- 插件名
	-- dependencies = { "kkharji/sqlite.lua" }, -- 依赖 SQLite，用于持久化 yank 历史
	event = "VeryLazy", -- 延迟加载（在 VeryLazy 事件触发时加载）
	config = function()
		-- Yanky 插件设置
		require("yanky").setup({
			ring = {
				storage = "shada", -- 使用 SQLite 存储 yank 历史，实现持久化
			},
			preserve_cursor_position = {
				enabled = true, -- 在 put 操作后保留光标位置
			},
			highlight = {
				on_put = true, -- 在 put（粘贴）操作后高亮粘贴内容
				on_yank = true, -- 在 yank（复制）操作后高亮复制内容
				timer = 500, -- 高亮持续时间，单位毫秒
			},
		})

		-- =======================
		-- Yanky 插件默认快捷键
		-- =======================
		-- 普通模式和可视模式下，p/P 绑定 YankyPutAfter / YankyPutBefore
		vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)") -- 粘贴到光标后
		vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)") -- 粘贴到光标前

		vim.keymap.set({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)") -- 粘贴到光标后，并更新寄存器
		vim.keymap.set({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)") -- 粘贴到光标前，并更新寄存器

		-- 快速切换 yank 历史条目
		vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)") -- 上一个历史条目
		vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)") -- 下一个历史条目

		-- 普通模式和可视模式下 y 绑定 YankyYank
		vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)") -- 使用 Yanky 的复制功能

		-- 打开 yank 历史列表
		vim.keymap.set(
			"n",
			"<leader>yl",
			"<cmd>YankyRingHistory<cr>", -- 显示 yank 历史列表，支持选择条目粘贴
			{ silent = true, desc = "打开寄存器列表" }
		)
	end,
}
