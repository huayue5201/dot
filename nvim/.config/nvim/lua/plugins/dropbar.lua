-- https://github.com/Bekaboo/dropbar.nvim?tab=readme-ov-file

return {
	"Bekaboo/dropbar.nvim",
	lazy = false,
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
					border = "shadow",
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
						or not vim.tbl_isempty(vim.lsp.get_clients({
							bufnr = buf,
							method = "textDocument/documentSymbol",
						}))
				end,
			},
			sources = {
				terminal = {
					-- icon = function(_)
					-- 	return M.opts.icons.kinds.symbols.Terminal or " "
					-- end,
					-- name = function(buf)
					-- 	local name = vim.api.nvim_buf_get_name(buf)
					-- 	-- the second result val is the terminal object
					-- 	local term = select(2, require("toggleterm.terminal").indentify(name))
					-- 	if term then
					-- 		return term.display_name or term.name
					-- 	else
					-- 		return name
					-- 	end
					-- end,
				},
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
		vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "dropbar: Pick symbols in winbar" })
		vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "dropbar: Go to start of current context" })
		vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "dropbar: Select next context" })
	end,
}
