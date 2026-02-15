-- https://github.com/serhez/bento.nvim
return {
	"serhez/bento.nvim",
	event = "BufWinEnter",
	config = function()
		require("bento").setup({
			main_keymap = "<S-tab>", -- 主切换/展开键
			lock_char = "🔒", -- 锁定缓冲区名前显示的字符
			max_open_buffers = nil, -- 最大缓冲区数量（nil = 无限制）
			buffer_deletion_metric = "frecency_access", -- 缓冲区删除的衡量指标（见下文）
			buffer_notify_on_delete = true, -- 删除缓冲区时是否通知（false 为静默删除）
			ordering_metric = "access", -- 缓冲区排序方式：nil（任意）、"access" 或 "edit"
			default_action = "open", -- 直接按下标签时的默认动作
			map_last_accessed = false, -- 是否映射一个键到上次访问的缓冲区（除了 main_keymap）

			ui = {
				mode = "floating", -- "floating" | "tabline"
				floating = {
					position = "middle-right", -- 位置选项，见下文
					offset_x = 0, -- 相对于位置的横向偏移量
					offset_y = 0, -- 相对于位置的纵向偏移量
					dash_char = "─", -- 折叠状态下用于连接线的字符
					border = "none", -- "rounded" | "single" | "double" 等（参见 :h winborder）
					label_padding = 1, -- 标签周围的填充空间
					minimal_menu = nil, -- nil | "dashed" | "filename" | "full"
					max_rendered_buffers = nil, -- nil（无限制）或数字（用于分页显示）
				},
				tabline = {
					left_page_symbol = "❮", -- 存在前序缓冲区时显示的符号
					right_page_symbol = "❯", -- 存在更多缓冲区时显示的符号
					separator_symbol = "│", -- 缓冲区组件之间的分隔符
				},
			},

			-- 高亮组
			highlights = {
				current = "Bold", -- 当前缓冲区文件名（在最后使用的编辑器窗口中）
				active = "Normal", -- 在其他窗口中可见的活动缓冲区
				inactive = "Comment", -- 非活动/隐藏的缓冲区文件名
				modified = "DiagnosticWarn", -- 已修改/未保存的缓冲区文件名和连接线
				inactive_dash = "Comment", -- 折叠状态下非活动缓冲区的连接线
				previous = "Search", -- 上一个缓冲区的标签（main_keymap 标签）
				label_open = "DiagnosticVirtualTextHint", -- "打开"操作模式下的标签样式
				label_delete = "DiagnosticVirtualTextError", -- "删除"操作模式下的标签样式
				label_vsplit = "DiagnosticVirtualTextInfo", -- "垂直分割"模式下的标签样式
				label_split = "DiagnosticVirtualTextInfo", -- "水平分割"模式下的标签样式
				label_lock = "DiagnosticVirtualTextWarn", -- "锁定"操作模式下的标签样式
				label_minimal = "Visual", -- 折叠的 "full" 模式下的标签样式
				window_bg = "BentoNormal", -- 菜单窗口背景
				page_indicator = "Comment", -- 分页指示器（浮动模式：● ○ ○，标签栏模式：❮/❯）
				separator = "Normal", -- 标签栏中缓冲区组件之间的分隔符
			},

			-- 自定义动作
			actions = {},
		})
	end,
}
