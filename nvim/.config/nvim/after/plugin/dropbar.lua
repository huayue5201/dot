-- https://github.com/Bekaboo/dropbar.nvim?tab=readme-ov-file

vim.g.now(function()
	vim.g.add({
		source = "Bekaboo/dropbar.nvim",
		depends = { "nvim-telescope/telescope-fzf-native.nvim" },
		hooks = {
			post_install = function()
				-- 运行构建命令（例如 make 或 cargo）
				vim.fn.system("cd ~/.local/share/nvim/site/pack/deps/opt/telescope-fzf-native.nvim && make")
			end,
		},
	})
	local dropbar = require("dropbar")
	dropbar.setup({
		menu = {
			win_configs = {
				border = "shadow",
			},
		},
		icons = {
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
		sources = {
			path = {
				max_depth = 10,
			},
			terminal = {
				name = function(buf)
					local name = vim.api.nvim_buf_get_name(buf)
					-- the second result val is the terminal object
					local term = select(2, require("toggleterm.terminal").indentify(name))
					if term then
						return term.display_name or term.name
					else
						return name
					end
				end,
			},
		},
	})
	local dropbar_api = require("dropbar.api")
	vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
	vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
	vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
end)
