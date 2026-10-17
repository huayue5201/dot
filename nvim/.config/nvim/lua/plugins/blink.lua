-- https://cmp.saghen.dev/configuration/keymap.html
---@diagnostic disable: redefined-local

return {
	"saghen/blink.cmp",
	sem_version = "1.*",
	-- TermEnter 必须显式列出：blink 只在普通 buffer 进插入/命令行时才加载，
	-- 新会话直接 :terminal 不会加载，term 补全与 t 模式键位都不生效。
	event = { "InsertEnter", "CmdlineEnter", "TermEnter" },
	dependencies = {
		"saghen/blink.lib",
		"xzbdmw/colorful-menu.nvim",
		"bramdelta/blink-dap",
		"mikavilpas/blink-ripgrep.nvim",
	},
	-- 使用预编译的 fuzzy 二进制（sem_version = "1.*" 会自动下载）；
	-- 如需从源码构建，改用：build = "cargo build --release"（或 :BlinkCmp build）。
	-- 注意旧写法 require("blink.cmp").build() 在 v1.10.x 已不存在，会报 nil。

	config = function()
		local cmp = require("blink.cmp")

		cmp.setup({
			fuzzy = { implementation = "prefer_rust_with_warning" },

			snippets = {
				expand = function(snippet)
					vim.snippet.expand(snippet)
				end,
				active = function(filter)
					return vim.snippet.active(filter)
				end,
				jump = function(direction)
					vim.snippet.jump(direction)
				end,
			},

			completion = {
				keyword = { range = "full" },
				accept = { auto_brackets = { enabled = true } },
				list = { selection = { preselect = false, auto_insert = true } },
				menu = {
					border = "rounded",
					draw = {
						padding = { 0, 1 },
						columns = { { "item_idx" }, { "kind_icon" }, { "label", gap = 1 }, { "kind" } },
						components = {
							item_idx = {
								text = function(ctx)
									return ctx.idx == 10 and "0" or ctx.idx >= 10 and " " or tostring(ctx.idx)
								end,
								highlight = "BlinkCmpItemIdx",
							},
							kind_icon = {
								text = function(ctx)
									return " " .. ctx.kind_icon .. ctx.icon_gap .. ""
								end,
							},
							label = {
								text = function(ctx)
									return require("colorful-menu").blink_components_text(ctx)
								end,
								highlight = function(ctx)
									return require("colorful-menu").blink_components_highlight(ctx)
								end,
							},
						},
					},
				},
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 500,
					window = { border = "rounded" },
				},
			},

			keymap = {
				preset = "default",
				["<Tab>"] = {
					"snippet_forward",
					"fallback",
				},
				["<A-1>"] = {
					function(cmp)
						cmp.accept({ index = 1 })
					end,
				},
				["<A-2>"] = {
					function(cmp)
						cmp.accept({ index = 2 })
					end,
				},
				["<A-3>"] = {
					function(cmp)
						cmp.accept({ index = 3 })
					end,
				},
				["<A-4>"] = {
					function(cmp)
						cmp.accept({ index = 4 })
					end,
				},
				["<A-5>"] = {
					function(cmp)
						cmp.accept({ index = 5 })
					end,
				},
				["<A-6>"] = {
					function(cmp)
						cmp.accept({ index = 6 })
					end,
				},
				["<A-7>"] = {
					function(cmp)
						cmp.accept({ index = 7 })
					end,
				},
				["<A-8>"] = {
					function(cmp)
						cmp.accept({ index = 8 })
					end,
				},
				["<A-9>"] = {
					function(cmp)
						cmp.accept({ index = 9 })
					end,
				},
				["<A-0>"] = {
					function(cmp)
						cmp.accept({ index = 10 })
					end,
				},
			},
			appearance = {
				-- use_nvim_cmp_as_default 已废弃（tokyonight 原生支持 blink，无需回退）
				nerd_font_variant = "mono",
			},

			signature = {
				enabled = true,
				window = { border = "rounded" },
			},

			sources = {
				-- dap 必须列在这里（或 per_filetype）才会启用，否则 provider 是死配置
				default = { "lsp", "path", "snippets", "buffer", "ripgrep", "dap", "sqmeow" },
				-- lazydev 不会自动注册，必须显式列出（仅 lua 文件）
				per_filetype = {
					lua = { "lazydev", inherit_defaults = true },
				},
				providers = {
					ripgrep = {
						module = "blink-ripgrep",
						name = "Ripgrep",
						opts = {},
					},
					dap = {
						name = "dap",
						module = "blink-dap",
						opts = {
							include_repl = true,
							filetypes = {
								python = { trigger_characters = { "." } },
							},
							dap_filetypes = { "dap-repl" },
						},
					},
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100,
					},
					-- ✅ 添加 cargo 源到 providers
					cargo = {
						name = "Cargo",
						module = "custom.blink.sources.cargo",
						-- 如果需要配置项可以在这里添加
						-- opts = {},
					},
					-- sqmeow 数据库补全：模块懒加载时会自动把 sqmeow 插件拉起来；
					-- 无活动连接时其 enabled() 返回 false，不会干扰普通补全。
					sqmeow = {
						name = "Sqmeow",
						module = "sqmeow.completion.blink",
					},
				},
				transform_items = function(ctx, items)
					local line = ctx.cursor[1] - 1
					-- ctx.cursor[2] 是 0-based 字节列，而 LSP 的 character 是 UTF-16 code unit
					local _, col = vim.str_utfindex(ctx.line, ctx.cursor[2])
					for _, item in ipairs(items) do
						if item.textEdit then
							if item.textEdit.range then
								local range_end = item.textEdit.range["end"]
								if range_end.line == line and range_end.character > col then
									range_end.character = col
								end
							elseif item.textEdit.insert then
								item.textEdit.range = item.textEdit.insert
								item.textEdit.replace = nil
							end
						end
					end
					return items
				end,
			},

			cmdline = {
				enabled = true,
				keymap = {
					preset = "cmdline",
					-- cmdline preset 会把左右箭头改成选补全项（select_prev/next），
					-- 这里还原成正常移动光标；仍可用 <C-n>/<C-p>/<Tab> 选补全。
					["<Left>"] = false,
					["<Right>"] = false,
				},
				sources = { "buffer", "cmdline" },
				completion = {
					trigger = {
						show_on_blocked_trigger_characters = {},
						show_on_x_blocked_trigger_characters = {},
					},
					list = {
						selection = {
							preselect = true,
							auto_insert = true,
						},
					},
					menu = {
						auto_show = function(ctx, _)
							return ctx.mode == "cmdwin"
						end,
					},
					ghost_text = { enabled = true },
				},
			},

			-- 终端里只做「手动触发」补全。
			-- 原因：term 用 inherit 会继承顶层 default preset，把 shell 的
			-- <Up>/<Down>（历史）、<C-b>/<C-f>（左右移动）、<C-e>/<C-y>/<C-p>/<C-n>
			-- 等 readline 键全部抢走；而 term 模式下并没有真正的 shell 补全源
			-- （blink 官方 term 支持仍是 TODO），自动弹菜单只有噪音。
			term = {
				enabled = true,
				keymap = {
					preset = "none", -- 不继承 default，键位还给 shell
					["<C-space>"] = { "show", "fallback" },
					["<Tab>"] = { "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					["<C-y>"] = { "select_and_accept", "fallback" },
					["<C-e>"] = { "hide", "fallback" },
				},
				-- term.sources 是字符串列表，只包含源名称；lsp/ripgrep/cargo 在 shell 里没用
				sources = { "path", "buffer" },
				completion = {
					menu = { auto_show = false },
					list = { selection = { preselect = false, auto_insert = false } },
					ghost_text = { enabled = false },
				},
			},
		})
	end,
}
