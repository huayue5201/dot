-- https://github.com/gbprod/yanky.nvim

return -- 推荐使用 lazy.nvim 方式
{
	"gbprod/yanky.nvim",
	event = "VeryLazy",
	dependencies = {
		-- 可选：使用 sqlite 存储更可靠（比 shada 稳定）
		{ "kkharji/sqlite.lua" },
	},
	opts = {
		-- 环形历史记录配置
		ring = {
			history_length = 100, -- 保存100条记录
			storage = "sqlite", -- sqlite / shada / memory
			storage_path = vim.fn.stdpath("data") .. "/databases/yanky.db",
			sync_with_numbered_registers = true, -- 同步到1-9号寄存器
			cancel_event = "update", -- 输入或移动光标后退出环形模式
			ignore_registers = { "_" }, -- 忽略黑洞寄存器
			update_register_on_cycle = false,
		},
		-- 系统剪贴板同步
		system_clipboard = {
			sync_with_ring = true, -- 自动把系统剪贴板内容加入历史
		},
		-- 高亮反馈
		highlight = {
			on_put = true, -- 粘贴时高亮
			on_yank = true, -- 复制时高亮
			timer = 500, -- 高亮持续时间(ms)
		},
		-- 复制后光标位置保持不变
		preserve_cursor_position = {
			enabled = true,
		},
		-- 文本对象 (可选)
		textobj = {
			enabled = true, -- 启用后可用 iy 选中上次粘贴的内容
		},
	},
	keys = {
		-- 基础复制粘贴 (必须)
		{ "y", "<Plug>(YankyYank)", mode = { "n", "x" }, desc = "Yank text" },
		{ "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put after cursor" },
		{ "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put before cursor" },
		{ "gp", "<Plug>(YankyGPutAfter)", mode = { "n", "x" }, desc = "Put after and leave cursor" },
		{ "gP", "<Plug>(YankyGPutBefore)", mode = { "n", "x" }, desc = "Put before and leave cursor" },

		-- 环形历史浏览 (粘贴后按 Ctrl-n / Ctrl-p 切换历史条目)
		{ "<c-p>", "<Plug>(YankyPreviousEntry)", desc = "Previous yank entry" },
		{ "<c-n>", "<Plug>(YankyNextEntry)", desc = "Next yank entry" },

		-- 特殊粘贴 (类似 unimpaired)
		{ "]p", "<Plug>(YankyPutIndentAfterLinewise)", desc = "Put and indent after (linewise)" },
		{ "[p", "<Plug>(YankyPutIndentBeforeLinewise)", desc = "Put and indent before (linewise)" },
		{ ">p", "<Plug>(YankyPutIndentAfterShiftRight)", desc = "Put and shift right" },
		{ "<p", "<Plug>(YankyPutIndentAfterShiftLeft)", desc = "Put and shift left" },
		{ "=p", "<Plug>(YankyPutAfterFilter)", desc = "Put and re-indent" },

		-- 打开历史选择器 (推荐)
		{ "<leader>yl", "<cmd>YankyRingHistory<cr>", mode = { "n", "x" }, desc = "Open yank history picker" },

		-- 文本对象: 选中上次粘贴的内容 (需要 textobj.enabled = true)
		{
			"iy",
			function()
				require("yanky.textobj").last_put()
			end,
			mode = { "o", "x" },
			desc = "Last pasted text",
		},
	},
}
