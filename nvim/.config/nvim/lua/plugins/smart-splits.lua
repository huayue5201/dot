-- https://github.com/smart-splits-nvim/smart-splits.nvim

return {
	"smart-splits-nvim/smart-splits.nvim",
	version = "^3.0.0", -- 锁定 v3 大版本，比 branch = "v3" 更稳定
	dependencies = {
		{
			"smart-splits-nvim/backend-ghostty",
			main = "smart-splits-backend-ghostty",
		},
	},
	keys = {
		-- 移动光标到相邻窗口（最高频，Alt+hjkl 单键）
		{
			"<A-h>",
			function()
				require("smart-splits").move_cursor_left()
			end,
			desc = "Smart-splits: 光标去左窗口",
		},
		{
			"<A-j>",
			function()
				require("smart-splits").move_cursor_down()
			end,
			desc = "Smart-splits: 光标去下窗口",
		},
		{
			"<A-k>",
			function()
				require("smart-splits").move_cursor_up()
			end,
			desc = "Smart-splits: 光标去上窗口",
		},
		{
			"<A-l>",
			function()
				require("smart-splits").move_cursor_right()
			end,
			desc = "Smart-splits: 光标去右窗口",
		},
		-- 调整窗口大小（<A-HJKL> = Alt+Shift+hjkl，单键组合以匹配 ghostty 协议）
		{
			"<A-H>",
			function()
				require("smart-splits").resize_left()
			end,
			desc = "Smart-splits: 左边界左移(变宽)",
		},
		{
			"<A-J>",
			function()
				require("smart-splits").resize_down()
			end,
			desc = "Smart-splits: 下边界下移(变高)",
		},
		{
			"<A-K>",
			function()
				require("smart-splits").resize_up()
			end,
			desc = "Smart-splits: 上边界上移(变高)",
		},
		{
			"<A-L>",
			function()
				require("smart-splits").resize_right()
			end,
			desc = "Smart-splits: 右边界右移(变宽)",
		},
		-- 交换窗口 buffer（<leader><leader> + hjkl）
		{
			"<leader><leader>h",
			function()
				require("smart-splits").swap_buf_left()
			end,
			desc = "Smart-splits: 与左窗口换 buffer",
		},
		{
			"<leader><leader>j",
			function()
				require("smart-splits").swap_buf_down()
			end,
			desc = "Smart-splits: 与下窗口换 buffer",
		},
		{
			"<leader><leader>k",
			function()
				require("smart-splits").swap_buf_up()
			end,
			desc = "Smart-splits: 与上窗口换 buffer",
		},
		{
			"<leader><leader>l",
			function()
				require("smart-splits").swap_buf_right()
			end,
			desc = "Smart-splits: 与右窗口换 buffer",
		},
	},
	opts = {
		mux = {
			backend = "smart-splits-backend-ghostty",
		},
		move = {
			at_edge = "stop", -- ghostty backend 要求
		},
		log = { file = false }, -- v3 默认会写日志文件，这里关掉
	},
}
