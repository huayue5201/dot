-- https://cmp.saghen.dev/configuration/keymap.html

return {
	"saghen/blink.cmp",
	version = "*",
	event = { "InsertEnter", "CmdlineEnter" },
	dependencies = {
		"saghen/blink.lib",
		"rafamadriz/friendly-snippets",
		"xzbdmw/colorful-menu.nvim",
		"bramdelta/blink-dap",
	},
	build = function()
		require("blink.cmp").build():wait(60000)
	end,

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		fuzzy = { implementation = "rust" },

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
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		signature = {
			enabled = true,
			window = { border = "rounded" },
		},

		sources = {
			default = function(ctx)
				local success, node = pcall(vim.treesitter.get_node)
				if
					success
					and node
					and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type())
				then
					return { "buffer" }
				elseif vim.bo.filetype == "lua" then
					return { "lsp", "path" }
				else
					return { "lsp", "path", "snippets", "buffer" }
				end
			end,
			providers = {
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
			},
			transform_items = function(ctx, items)
				local line = ctx.cursor[1] - 1
				local col = ctx.cursor[2]
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
			keymap = { preset = "inherit" },
			completion = { menu = { auto_show = true } },
		},
	},
}
