-- https://github.com/ahkohd/buffer-sticks.nvim

return {
	"ahkohd/buffer-sticks.nvim",
	event = "VeryLazy",
	keys = {
		{
			"gb",
			function()
				BufferSticks.list({ action = "open" })
			end,
			desc = "buffer-sticks: Jump to buffer",
		},
		{
			"<leader>cb",
			function()
				BufferSticks.list({ action = "close" })
			end,
			desc = "buffer-sticks: Close buffer",
		},
		-- {
		-- 	"<leader>p",
		-- 	function()
		-- 		BufferSticks.list({
		-- 			action = function(buffer, leave)
		-- 				print("Selected: " .. buffer.name)
		-- 				leave()
		-- 			end
		-- 		})
		-- 	end,
		-- 	desc = "buffer-sticks: Buffer picker",
		-- },
	},
	config = function()
		local sticks = require("buffer-sticks")
		sticks.setup({
			offset = { x = 0, y = 0 }, -- 位置偏移（正值表示从右边缘向内移动）
			padding = { top = 0, right = 1, bottom = 0, left = 1 }, -- 浮动窗口内边距
			active_char = "──", -- 活动缓冲区的字符
			inactive_char = " ─", -- 非活动缓冲区的字符
			alternate_char = " ─", -- 备用缓冲区的字符
			active_modified_char = "──", -- 活动修改缓冲区（未保存更改）的字符
			inactive_modified_char = " ─", -- 非活动修改缓冲区（未保存更改）的字符
			alternate_modified_char = " ─", -- 备用修改缓冲区（未保存更改）的字符
			transparent = true, -- 移除背景色（显示终端/编辑器背景）
			auto_hide = true, -- 当光标移到浮动窗口上时自动隐藏（默认：true）
			label = { show = "list" }, -- 标签显示： "always"（总是显示）、"list"（仅在列表模式下显示）、"never"（从不显示）
			list = {
				show = { "filename", "space", "label" }, -- 列表模式显示选项（显示文件名、空格和标签）
				active_indicator = "•", -- 列表模式下选中项的指示符（例如，用于箭头导航）
				keys = {
					close_buffer = "<C-q>", -- 在列表模式中关闭缓冲区的快捷键
					move_up = "<Up>", -- 在列表模式中向上移动选择的快捷键
					move_down = "<Down>", -- 在列表模式中向下移动选择的快捷键
				},
				filter = {
					title = "➜ ", -- 当过滤器输入框不为空时的提示标题
					title_empty = "Filter", -- 当过滤器输入框为空时的提示标题
					active_indicator = "•", -- 过滤器模式下选中项的指示符
					fuzzy_cutoff = 100, -- 模糊匹配算法的截断值（默认：100）
					keys = {
						enter = "/", -- 进入过滤器模式的快捷键
						confirm = "<CR>", -- 确认选择的快捷键
						exit = "<Esc>", -- 退出过滤器模式的快捷键
						move_up = "<Up>", -- 在过滤器模式中向上移动选择的快捷键
						move_down = "<Down>", -- 在过滤器模式中向下移动选择的快捷键
					},
				},
			},
			preview = {
				enabled = false, -- 启用缓冲区预览（在导航时显示）
			},
			winblend = 30, -- 窗口混合程度（0-100，0=不透明，100=完全透明）
			filter = {
				filetypes = { "help", "qf" }, -- 排除的文件类型（例如： "NvimTree"、"neo-tree"、"Trouble"）
				buftypes = { "terminal" }, -- 排除的缓冲区类型（例如："help"、"quickfix"、"nofile"）
				names = { ".*%.git/.*", "^/tmp/.*" }, -- 排除符合 Lua 模式的缓冲区
			},
			highlights = {
				active = { link = "Statement" },
				alternate = { link = "StorageClass" },
				inactive = { link = "Whitespace" },
				active_modified = { link = "Constant" },
				alternate_modified = { link = "Constant" },
				inactive_modified = { link = "Constant" },
				label = { link = "Comment" },
				filter_selected = { link = "Statement" },
				filter_title = { link = "Comment" },
				list_selected = { link = "Statement" },
			},
		})
		sticks.show()
	end,
}
