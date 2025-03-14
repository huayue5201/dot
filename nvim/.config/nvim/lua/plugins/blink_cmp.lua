-- https://cmp.saghen.dev/configuration/keymap.html

return {
	"saghen/blink.cmp",
	event = "InsertEnter",
	-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	build = "cargo build --release",
	---@module 'blink.cmp'
	---@type blink.cmp.Config
	config = function()
		require("blink.cmp").setup({
			-- completion 配置：定义补全功能的行为和显示
			completion = {
				-- 关键字匹配范围设置：
				-- 'prefix'：仅匹配光标前的文本
				-- 'full'：匹配光标前后全部文本
				-- 示例：对于 'foo_|_bar'，'prefix' 匹配 'foo_'，'full' 匹配 'foo__bar'
				keyword = { range = "full" },
				-- 自动括号配置：
				-- 启用自动插入括号（注意：某些 LSP 可能会自行添加括号）
				accept = { auto_brackets = { enabled = true } },
				-- 默认不预选补全项，只有在用户选择时才自动插入
				list = { selection = { preselect = true, auto_insert = true } },
				-- 补全菜单设置：
				menu = {
					border = "shadow",
					draw = {
						columns = {
							{ "kind_icon" }, -- 显示补全项的图标
							{ "label", "label_description", gap = 1 }, -- 显示补全项的标签和描述，图标与文字之间留1个空格
							{ "kind" }, -- 显示补全项的类型
						},
						-- 启用基于 treesitter 的菜单文本高亮（依赖 LSP 高亮规则）
						treesitter = { "lsp" },
					},
				},
				-- 文档预览设置：
				documentation = {
					auto_show = true, -- 自动显示补全文档预览
					auto_show_delay_ms = 500, -- 延迟 500 毫秒后自动弹出文档窗口
					window = { border = "rounded" },
				},
			},
			-- keymap 配置：定义补全键映射及其行为
			keymap = {
				preset = "default", -- 使用默认键映射方案（类似内置补全）
				-- ["<CR>"] = { "accept", "fallback" }, -- 将回车键设置为接受补全或执行后备操作
			},
			-- appearance 配置：界面外观及图标显示设置
			appearance = {
				-- 当主题不支持 blink.cmp 的高亮效果时，使用 nvim-cmp 默认高亮组
				use_nvim_cmp_as_default = true,
				-- 设置 Nerd Font 变体：
				-- "mono" 表示使用 Nerd Font Mono；"normal" 表示使用标准 Nerd Font
				-- 此设置用于调整图标间距以确保对齐
				nerd_font_variant = "mono",
			},
			-- 签名帮助配置：启用并设置签名提示窗口的外观
			signature = {
				enabled = true, -- 启用签名提示功能
				window = { border = "rounded" },
			},
			-- 补全源配置：定义默认启用的补全提供者
			sources = {
				default = { "lsp", "path", "snippets", "buffer" }, -- 默认补全源：LSP、文件路径、代码片段、缓冲区内容
			},
		})
	end,
}
