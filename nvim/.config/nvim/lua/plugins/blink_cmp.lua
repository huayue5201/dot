-- https://cmp.saghen.dev/configuration/keymap.html

return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	-- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
	build = "cargo build --release",
	dependencies = {
		"xzbdmw/colorful-menu.nvim",
	},

	---@diagnostic disable: missing-fields
	config = function()
		local capabilities = vim.lsp.protocol.make_client_capabilities()

		-- ❌ 强烈建议：不要启用 onTypeFormatting
		-- rust-analyzer + blink.cmp + preview 下极易出 offset 问题
		capabilities
			.textDocument--[[@cast -?]]
			.onTypeFormatting = nil

		-- 先让 blink.cmp 扩展能力（它只管补全）
		capabilities = vim.tbl_deep_extend(
			"keep", -- 注意：不是 force
			capabilities,
			require("blink.cmp").get_lsp_capabilities()
		)

		-- 再补充你自己的能力（只补充，不覆盖）
		capabilities.textDocument = capabilities.textDocument or {}
		capabilities.textDocument.foldingRange = {
			dynamicRegistration = false,
			lineFoldingOnly = true,
		}

		---@diagnostic disable-next-line: param-type-mismatch
		require("blink.cmp").setup({
			fuzzy = { implementation = "prefer_rust_with_warning" },
			snippets = {
				-- Function to use when expanding LSP provided snippets
				expand = function(snippet)
					vim.snippet.expand(snippet)
				end,
				-- Function to use when checking if a snippet is active
				active = function(filter)
					return vim.snippet.active(filter)
				end,
				-- Function to use when jumping between tab stops in a snippet, where direction can be negative or positive
				jump = function(direction)
					vim.snippet.jump(direction)
				end,
			},
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
				list = { selection = { preselect = false, auto_insert = true } },
				-- 补全菜单设置：
				menu = {
					border = "rounded",
					draw = {
						-- We don't need label_description now because label and label_description are already
						-- combined together in label by colorful-menu.nvim.
						columns = { { "kind_icon" }, { "label", gap = 1 }, { "kind" } },
						components = {
							label = {
								text = function(ctx)
									return require("colorful-menu").blink_components_text(ctx)
								end,
								highlight = function(ctx)
									return require("colorful-menu").blink_components_highlight(ctx)
								end,
							},
						},
						-- columns = {
						-- 	{ "kind_icon" }, -- 显示补全项的图标
						-- 	{ "label", "label_description", gap = 1 }, -- 显示补全项的标签和描述，图标与文字之间留1个空格
						-- 	{ "kind" }, -- 显示补全项的类型
						-- },
						-- 启用基于 treesitter 的菜单文本高亮（依赖 LSP 高亮规则）
						-- treesitter = { "lsp" },
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
				preset = "enter",
				["<Tab>"] = {
					function(cmp)
						if cmp.is_menu_visible() then
							return require("blink.cmp").select_next()
						elseif cmp.snippet_active() then
							return cmp.snippet_forward()
						end
					end,
					"fallback",
				},
				["<S-Tab>"] = {
					function(cmp)
						if cmp.is_menu_visible() then
							return require("blink.cmp").select_prev()
						elseif cmp.snippet_active() then
							return cmp.snippet_backward()
						end
					end,
					"fallback",
				},
				["<C-e>"] = { "hide", "show" },
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
				default = { "lazydev", "buffer", "lsp", "path", "snippets", "cmdline" }, -- 默认补全源：LSP、文件路径、代码片段、缓冲区内容
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						-- make lazydev completions top priority (see `:h blink.cmp`)
						score_offset = 100,
					},
				},
				transform_items = function(ctx, items)
					local line = ctx.cursor[1]--[[@cast -?]]
						- 1
					local col = ctx.cursor[2]
					for _, item in ipairs(items) do
						if item.textEdit then
							if item.textEdit.range then
								-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textEdit
								-- trim edit range after cursor
								local range_end = item.textEdit.range["end"]
								if range_end.line == line and range_end.character > col then
									range_end.character = col
								end
							elseif item.textEdit.insert then
								---@diagnostic disable-next-line: inject-field
								-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#insertReplaceEdit
								-- always use insert range
								item.textEdit.range = item.textEdit.insert
								item.textEdit.replace = nil
							end
						end
					end
					return items
				end,
			},
			cmdline = {
				enabled = false, -- 命令行补全
				keymap = { preset = "inherit" },
				completion = { menu = { auto_show = true } },
			},
		})
	end,
}
