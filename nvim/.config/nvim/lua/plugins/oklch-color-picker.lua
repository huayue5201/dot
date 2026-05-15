-- https://github.com/eero-lehtinen/oklch-color-picker.nvim

return {
	"eero-lehtinen/oklch-color-picker.nvim",
	version = "*",
	keys = {
		{
			"<leader>rv",
			function()
				require("oklch-color-picker").pick_under_cursor()
			end,
			desc = "Color pick under cursor",
		},
	},
	config = function()
		require("oklch-color-picker").setup({
			highlight = {
				enabled = true, -- 是否启用高亮

				-- 异步延迟（毫秒）
				edit_delay = 60, -- 编辑后延迟高亮更新时间
				scroll_delay = 0, -- 滚动后延迟高亮更新时间

				-- 高亮样式选项：
				-- 'background'              : 背景色高亮
				-- 'foreground'              : 前景色高亮
				-- 'virtual_left'            : 左侧虚拟文本
				-- 'virtual_eol'             : 行尾虚拟文本
				-- 'foreground+virtual_left' : 前景色 + 左侧虚拟文本
				-- 'foreground+virtual_eol'  : 前景色 + 行尾虚拟文本
				style = "background",
				bold = false, -- 是否粗体
				italic = false, -- 是否斜体

				-- 虚拟文本符号（'● ' 也不错，nerd字体有更大的形状如 ' '、'󰝤 '、' '）
				virtual_text = "■ ",

				-- 优先级（默认低于用户自定义高亮，详见 :help vim.highlight.priorities）
				priority = 175,

				-- 忽略这些文件类型，不附加高亮
				ignore_ft = { "blink-cmp-menu" },

				-- 当使用 'foreground' 或 'virtual' 样式时，如果找到的颜色与编辑器背景太接近，
				-- 会对背景进行轻微着色调整。
				-- 设置 `emphasis = false` 可禁用此功能。
				emphasis = {
					-- 触发强调的阈值（0..1），表示颜色与背景的距离
					-- 第一个值用于深色主题，第二个用于浅色主题
					threshold = { 0.1, 0.17 },
					-- 颜色偏移量（0..255），第一个值用于深色，第二个用于浅色
					amount = { 45, -80 },
				},

				-- 允许高亮颜色的 LSP 客户端列表：
				-- 默认只启用性能较好且有用的 LSP
				-- 设置 `enabled_lsps = true` 可启用所有 LSP
				enabled_lsps = { "tailwindcss", "cssls", "css_variables" },

				-- 异步延迟（毫秒），LSP 本身也有自己的延迟
				lsp_delay = 120,

				-- 禁用 Neovim 0.12 引入的内置 LSP 颜色高亮，避免冲突
				disable_builtin_lsp_colors = true,
			},

			-- 颜色模式匹配规则
			patterns = {
				hex = { priority = -1, "()#%x%x%x+%f[%W]()" }, -- 十六进制颜色如 #FFF #FFFFFF
				hex_literal = { priority = -1, "()0x%x%x%x%x%x%x+%f[%W]()" }, -- 十六进制字面量如 0xFF00FF

				-- RGB 和 HSL 支持现代和旧版格式：
				-- rgb(10 10 10 / 50%) 和 rgba(10, 10, 10, 0.5)
				css_rgb = { priority = -1, "()rgba?%(.-%)()" }, -- RGB/RGBA 颜色
				css_hsl = { priority = -1, "()hsla?%(.-%)()" }, -- HSL/HSLA 颜色
				css_oklch = { priority = -1, "()oklch%([^,]-%)()" }, -- OKLCH 颜色

				tailwind = {
					priority = -2,
					custom_parse = tailwind.custom_parse, -- 自定义解析函数
					"%f[%w][%l%-]-%-()%l-%-%d%d%d?%f[%W]()", -- Tailwind CSS 类名匹配
				},

				-- 匹配括号内的任意数字、点、逗号或空格
				numbers_in_brackets = { priority = -10, "%(()[%d.,%s]+()%)" },
			},

			register_cmds = true, -- 是否注册命令

			auto_download = true, -- 自动下载 Rust 二进制文件

			-- 在 WSL 上使用 Windows 版本的应用程序，而不是不可靠的 WSLg
			wsl_use_windows_app = true,

			log_level = vim.log.levels.INFO, -- 日志级别
		})
	end,
}
