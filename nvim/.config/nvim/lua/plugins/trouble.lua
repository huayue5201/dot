-- https://github.com/folke/trouble.nvim

return {
	"folke/trouble.nvim",
	event = "VeryLazy",
	opts = {
		win = {
			type = "split", -- 分割窗口
			position = "bottom", -- 位置
			size = 50, -- ← 这里可以设置大小（行数）
		},
		modes = {
			test = {
				mode = "diagnostics",
				preview = {
					type = "split",
					relative = "win",
					position = "right",
					size = 0.3,
				},
			},
		},
	}, -- for default options, refer to the configuration section for custom setup.
	cmd = "Trouble",
	keys = {
		{
			"<leader>xx",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "诊断信息 (Trouble)",
		},
		{
			"<leader>xX",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "当前缓冲区诊断 (Trouble)",
		},
		{
			"<leader>xf",
			"<cmd>Trouble symbols toggle focus=false<cr>",
			desc = "符号列表 (Trouble)",
		},
		{
			"<leader>xF",
			"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
			desc = "LSP 定义/引用/... (Trouble)",
		},
		{
			"<leader>xi",
			"<cmd>Trouble lsp_incoming_calls<cr>",
			desc = "LSP 被调用位置 (Trouble)",
		},
		{
			"<leader>xo",
			"<cmd>Trouble lsp_outgoing_calls<cr>",
			desc = "LSP 调用位置 (Trouble)",
		},
	},
}
