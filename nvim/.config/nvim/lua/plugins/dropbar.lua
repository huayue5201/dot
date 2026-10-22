-- https://github.com/Bekaboo/dropbar.nvim

return {
	"Bekaboo/dropbar.nvim",
	dependencies = {
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
	},
	config = function()
		vim.api.nvim_set_hl(0, "htmlTag", { fg = "#FF8247" }) -- 后续图标的颜色

		local dropbar = require("dropbar")
		dropbar.setup({
			menu = {
				win_configs = {
					border = "rounded",
				},
				-- 上游默认的 <LeftMouse> 处理器（configs.lua:406-416）直接把 getmousepos()
				-- 的行号丢给 menu:click_at() → nvim_win_set_cursor()（menu.lua:315），
				-- 点到 float 边框/滚动条帧或菜单刚重绘后行号会超出 buffer 行数，报
				-- E5108 "Invalid cursor line: out of range"。这里加行号边界检查。
				keymaps = {
					["<LeftMouse>"] = function()
						local utils = require("dropbar.utils")
						local current = utils.menu.get_current()
						if not current then
							return
						end
						local mouse = vim.fn.getmousepos()
						local clicked = utils.menu.get({ win = mouse.winid })
						if clicked and clicked.buf and vim.api.nvim_buf_is_valid(clicked.buf) then
							local n_lines = vim.api.nvim_buf_line_count(clicked.buf)
							if mouse.line >= 1 and mouse.line <= n_lines then
								clicked:click_at({ mouse.line, math.max(0, mouse.column - 1) }, nil, 1, "l")
								return
							end
						end
						-- 没点在菜单内容行上：关掉菜单并把光标放到点击的窗口
						utils.menu.exec("close")
						utils.bar.exec("update_current_context_hl")
						if vim.api.nvim_win_is_valid(mouse.winid) then
							vim.api.nvim_set_current_win(mouse.winid)
						end
					end,
				},
			},
			icons = {
				ui = {
					bar = {
						separator = " > ",
						extends = "…",
					},
					menu = {
						separator = " ",
						indicator = "󱞩 ",
					},
				},
				enable = true,
				kinds = {
					symbols = {
						Array = "󰅪 ",
						Boolean = " ",
						BreakStatement = "󰙧 ",
						Call = "󰃷 ",
						CaseStatement = "󱃙 ",
						Class = " ",
						Color = "󰏘 ",
						Constant = "󰏿 ",
						Constructor = " ",
						ContinueStatement = "→ ",
						Copilot = " ",
						Declaration = "󰙠 ",
						Delete = "󰩺 ",
						DoStatement = "󰑖 ",
						Enum = " ",
						EnumMember = " ",
						Event = " ",
						Field = " ",
						File = "󰈔 ",
						-- Folder = "󰉋 ",
						Folder = "",
						ForStatement = "󰑖 ",
						Function = "󰊕 ",
						H1Marker = "󰉫 ", -- Used by markdown treesitter parser
						H2Marker = "󰉬 ",
						H3Marker = "󰉭 ",
						H4Marker = "󰉮 ",
						H5Marker = "󰉯 ",
						H6Marker = "󰉰 ",
						Identifier = "󰀫 ",
						IfStatement = "󰇉 ",
						Interface = " ",
						Keyword = "󰌋 ",
						List = "󰅪 ",
						Log = "󰦪 ",
						Lsp = " ",
						Macro = "󰁌 ",
						MarkdownH1 = "󰉫 ", -- Used by builtin markdown source
						MarkdownH2 = "󰉬 ",
						MarkdownH3 = "󰉭 ",
						MarkdownH4 = "󰉮 ",
						MarkdownH5 = "󰉯 ",
						MarkdownH6 = "󰉰 ",
						Method = "󰆧 ",
						Module = "󰏗 ",
						Namespace = "󰅩 ",
						Null = "󰢤 ",
						Number = "󰎠 ",
						Object = "󰅩 ",
						Operator = "󰆕 ",
						Package = "󰆦 ",
						Pair = "󰅪 ",
						Property = " ",
						Reference = "󰦾 ",
						Regex = " ",
						Repeat = "󰑖 ",
						Scope = "󰅩 ",
						Snippet = "󰩫 ",
						Specifier = "󰦪 ",
						Statement = "󰅩 ",
						String = "󰉾 ",
						Struct = " ",
						SwitchStatement = "󰺟 ",
						Table = "󰅩 ",
						Terminal = " ",
						Text = " ",
						Type = " ",
						TypeParameter = "󰆩 ",
						Unit = " ",
						Value = "󰎠 ",
						Variable = "󰀫 ",
						WhileStatement = "󰑖 ",
					},
				},
			},
			bar = {
				enable = function(buf, win, _)
					if
						not vim.api.nvim_buf_is_valid(buf)
						or not vim.api.nvim_win_is_valid(win)
						or vim.fn.win_gettype(win) ~= ""
						or vim.wo[win].winbar ~= ""
						or vim.bo[buf].ft == "help"
						or vim.bo[buf].ft == "todo2drawer" -- todo2 抽屉（ui buffer，不显示 winbar）
					then
						return false
					end

					local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(buf))
					if stat and stat.size > 1024 * 1024 then
						return false
					end

					return vim.bo[buf].ft == "markdown"
						or vim.bo[buf].ft == "oil" -- enable in oil buffers
						or vim.bo[buf].ft == "fugitive" -- enable in fugitive buffers
						or pcall(vim.treesitter.get_parser, buf)
						or next(vim.lsp.get_clients({
								bufnr = buf,
								method = "textDocument/documentSymbol",
							}))
							~= nil
				end,
			},
			sources = {
				path = {
					max_depth = 10,
					relative_to = function(buf, win)
						-- Show full path in oil or fugitive buffers
						local bufname = vim.api.nvim_buf_get_name(buf)
						if vim.startswith(bufname, "oil://") or vim.startswith(bufname, "fugitive://") then
							local root = bufname:gsub("^%S+://", "", 1)
							while root and root ~= vim.fs.dirname(root) do
								root = vim.fs.dirname(root)
							end
							return root
						end

						local ok, cwd = pcall(vim.fn.getcwd, win)
						return ok and cwd or vim.fn.getcwd()
					end,
				},
			},
			fzf = {
				prompt = "%#htmlTag# :",
			},
		})
		vim.ui.select = require("dropbar.utils.menu").select
		local dropbar_api = require("dropbar.api")
		vim.keymap.set("n", "<Leader>s;", dropbar_api.pick, { desc = "dropbar: Pick symbols in winbar" })
		vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "dropbar: Go to start of current context" })
		vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "dropbar: Select next context" })
	end,
}
