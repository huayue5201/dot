-- https://github.com/serhez/bento.nvim
return {
	"serhez/bento.nvim",
	event = "BufWinEnter",
	config = function()
		require("bento").setup({

			------------------------------------------------------------------
			-- 核心行为
			------------------------------------------------------------------
			main_keymap = "<Tab>", -- 主触发键（强烈推荐 <Tab> 或 ;）
			max_open_buffers = nil, -- 不限制 buffer 数
			ordering_metric = "access", -- 按最近访问排序（最符合直觉）
			buffer_deletion_metric = "frecency_access",
			buffer_notify_on_delete = false,
			default_action = "open",

			------------------------------------------------------------------
			-- UI
			------------------------------------------------------------------
			ui = {
				mode = "floating",
				floating = {
					position = "middle-right",
					offset_x = 0,
					offset_y = 0,
					dash_char = "─",
					label_padding = 1,
					minimal_menu = nil, -- 完整模式，调试/学习更友好
					max_rendered_buffers = 20, -- 防止 buffer 多时卡顿
				},
			},

			------------------------------------------------------------------
			-- 高亮（尽量使用已有 Diagnostic / UI 语义）
			------------------------------------------------------------------
			highlights = {
				current = "Bold",
				active = "Normal",
				inactive = "Comment",
				modified = "DiagnosticWarn",

				previous = "Search",

				label_open = "DiagnosticVirtualTextHint",
				label_delete = "DiagnosticVirtualTextError",
				label_split = "DiagnosticVirtualTextInfo",
				label_vsplit = "DiagnosticVirtualTextInfo",
				label_lock = "DiagnosticVirtualTextWarn",

				window_bg = "NormalFloat",
				page_indicator = "Comment",
			},
		})
	end,
}
