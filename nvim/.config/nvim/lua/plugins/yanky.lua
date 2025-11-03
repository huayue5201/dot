-- Yanky.nvim 插件配置
-- 官方文档: https://github.com/gbprod/yanky.nvim#ringhistory_length

return {
	"gbprod/yanky.nvim", -- 插件名
	-- dependencies = { "kkharji/sqlite.lua" }, -- 依赖 SQLite，用于持久化 yank 历史
	dependencies = { "nvimtools/hydra.nvim" },
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

		-- 普通模式和可视模式下 y 绑定 YankyYank
		vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)") -- 使用 Yanky 的复制功能

		-- 打开 yank 历史列表
		vim.keymap.set(
			"n",
			"<leader>yl",
			"<cmd>YankyRingHistory<cr>", -- 显示 yank 历史列表，支持选择条目粘贴
			{ silent = true, desc = "打开寄存器列表" }
		)

		local Hydra = require("hydra")

		local function t(str)
			return vim.api.nvim_replace_termcodes(str, true, true, true)
		end

		local yanky_hydra = Hydra({
			name = "Yank ring",
			mode = "n",
			heads = {
				{ "p", "<Plug>(YankyPutAfter)", { desc = "After" } },
				{ "P", "<Plug>(YankyPutBefore)", { desc = "Before" } },
				{ "<c-p>", "<Plug>(YankyPreviousEntry)", { private = true, desc = "↑" } },
				{ "<c-n>", "<Plug>(YankyNextEntry)", { private = true, desc = "↓" } },
			},
		})

		-- choose/change the mappings if you want
		for key, putAction in pairs({
			["p"] = "<Plug>(YankyPutAfter)",
			["P"] = "<Plug>(YankyPutBefore)",
			["gp"] = "<Plug>(YankyGPutAfter)",
			["gP"] = "<Plug>(YankyGPutBefore)",
		}) do
			vim.keymap.set({ "n", "x" }, key, function()
				vim.fn.feedkeys(t(putAction))
				yanky_hydra:activate()
			end)
		end

		-- choose/change the mappings if you want
		for key, putAction in pairs({
			["]p"] = "<Plug>(YankyPutIndentAfterLinewise)",
			["[p"] = "<Plug>(YankyPutIndentBeforeLinewise)",
			["]P"] = "<Plug>(YankyPutIndentAfterLinewise)",
			["[P"] = "<Plug>(YankyPutIndentBeforeLinewise)",

			[">p"] = "<Plug>(YankyPutIndentAfterShiftRight)",
			["<p"] = "<Plug>(YankyPutIndentAfterShiftLeft)",
			[">P"] = "<Plug>(YankyPutIndentBeforeShiftRight)",
			["<P"] = "<Plug>(YankyPutIndentBeforeShiftLeft)",

			["=p"] = "<Plug>(YankyPutAfterFilter)",
			["=P"] = "<Plug>(YankyPutBeforeFilter)",
		}) do
			vim.keymap.set("n", key, function()
				vim.fn.feedkeys(t(putAction))
				yanky_hydra:activate()
			end)
		end
	end,
}
