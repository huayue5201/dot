-- https://github.com/hrsh7th/nvim-cmp

return {
	"hrsh7th/nvim-cmp",
	event = { "InsertEnter" },
	dependencies = {
		-- https://github.com/hrsh7th/cmp-nvim-lsp
		"hrsh7th/cmp-nvim-lsp",
		-- https://github.com/hrsh7th/cmp-buffer
		"hrsh7th/cmp-buffer",
		-- https://github.com/hrsh7th/cmp-path
		"hrsh7th/cmp-path",
		-- https://github.com/hrsh7th/cmp-nvim-lsp-signature-help
		"hrsh7th/cmp-nvim-lsp-signature-help",
	},
	init = function()
		vim.opt.completeopt = { "menu", "menuone", "noselect" }
	end,
	config = function()
		local has_words_before = function()
			unpack = unpack or table.unpack
			local line, col = unpack(vim.api.nvim_win_get_cursor(0))
			return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
		end

		-- Set up nvim-cmp.
		local cmp = require("cmp")
		-- Customization for Pmenu
		vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#282C34", fg = "NONE" })
		vim.api.nvim_set_hl(0, "Pmenu", { fg = "#C5CDD9", bg = "#22252A" })

		vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", { fg = "#7E8294", bg = "NONE", strikethrough = true })
		vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { fg = "#82AAFF", bg = "NONE", bold = true })
		vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { fg = "#82AAFF", bg = "NONE", bold = true })
		vim.api.nvim_set_hl(0, "CmpItemMenu", { fg = "#C792EA", bg = "NONE", italic = true })

		vim.api.nvim_set_hl(0, "CmpItemKindField", { fg = "#EED8DA", bg = "#FF0088" })
		vim.api.nvim_set_hl(0, "CmpItemKindProperty", { fg = "#EED8DA", bg = "#FF0088" })
		vim.api.nvim_set_hl(0, "CmpItemKindEvent", { fg = "#EED8DA", bg = "#FF0088" })

		vim.api.nvim_set_hl(0, "CmpItemKindText", { fg = "#C3E88D", bg = "#00A400" })
		vim.api.nvim_set_hl(0, "CmpItemKindEnum", { fg = "#C3E88D", bg = "#00A400" })
		vim.api.nvim_set_hl(0, "CmpItemKindKeyword", { fg = "#C3E88D", bg = "#00A400" })

		vim.api.nvim_set_hl(0, "CmpItemKindConstant", { fg = "#FFE082", bg = "#009FCC" })
		vim.api.nvim_set_hl(0, "CmpItemKindConstructor", { fg = "#FFE082", bg = "#009FCC" })
		vim.api.nvim_set_hl(0, "CmpItemKindReference", { fg = "#FFE082", bg = "#009FCC" })

		vim.api.nvim_set_hl(0, "CmpItemKindFunction", { fg = "#EADFF0", bg = "#660077" })
		vim.api.nvim_set_hl(0, "CmpItemKindStruct", { fg = "#EADFF0", bg = "#660077" })
		vim.api.nvim_set_hl(0, "CmpItemKindClass", { fg = "#EADFF0", bg = "#660077" })
		vim.api.nvim_set_hl(0, "CmpItemKindModule", { fg = "#EADFF0", bg = "#660077" })
		vim.api.nvim_set_hl(0, "CmpItemKindOperator", { fg = "#EADFF0", bg = "#660077" })

		vim.api.nvim_set_hl(0, "CmpItemKindVariable", { fg = "#C5CDD9", bg = "#7E8294" })
		vim.api.nvim_set_hl(0, "CmpItemKindFile", { fg = "#C5CDD9", bg = "#7E8294" })

		vim.api.nvim_set_hl(0, "CmpItemKindUnit", { fg = "#F5EBD9", bg = "#EE7700" })
		vim.api.nvim_set_hl(0, "CmpItemKindSnippet", { fg = "#F5EBD9", bg = "#EE7700" })
		vim.api.nvim_set_hl(0, "CmpItemKindFolder", { fg = "#F5EBD9", bg = "#EE7700" })

		vim.api.nvim_set_hl(0, "CmpItemKindMethod", { fg = "#DDE5F5", bg = "#6C8ED4" })
		vim.api.nvim_set_hl(0, "CmpItemKindValue", { fg = "#DDE5F5", bg = "#6C8ED4" })
		vim.api.nvim_set_hl(0, "CmpItemKindEnumMember", { fg = "#DDE5F5", bg = "#6C8ED4" })

		vim.api.nvim_set_hl(0, "CmpItemKindInterface", { fg = "#D8EEEB", bg = "#58B5A8" })
		vim.api.nvim_set_hl(0, "CmpItemKindColor", { fg = "#D8EEEB", bg = "#58B5A8" })
		vim.api.nvim_set_hl(0, "CmpItemKindTypeParameter", { fg = "#D8EEEB", bg = "#58B5A8" })

		local kind_icons = {
			Text = "  ",
			Method = " 󰆧 ",
			Function = " 󰊕 ",
			Constructor = "  ",
			Field = " 󰇽 ",
			Variable = " 󰂡 ",
			Class = " 󰠱 ",
			Interface = "  ",
			Module = "  ",
			Property = " 󰜢 ",
			Unit = "  ",
			Value = " 󰎠 ",
			Enum = "  ",
			Keyword = " 󰌋 ",
			Snippet = "  ",
			Color = " 󰏘 ",
			File = " 󰈙 ",
			Reference = "  ",
			Folder = " 󰉋 ",
			EnumMember = "  ",
			Constant = " 󰏿 ",
			Struct = "   ",
			Event = "  ",
			Operator = " 󰆕 ",
			TypeParameter = " 󰅲 ",
		}

		cmp.setup({
			completion = {
				-- 触发补全的字符数
				keyword_length = 2,
			},

			-- 片段支持
			snippet = {
				expand = function(args)
					vim.snippet.expand(args.body)
				end,
			},

			-- sources列表
			sources = {
				{ name = "nvim_lsp" },
				{ name = "buffer" },
				{ name = "path" },
				{ name = "nvim_lsp_signature_help" },
			},

			-- 补全弹窗格式设置
			window = {
				-- nvim_lsp_signature_help弹窗大小
				documentation = {
					maxheight = 15,
					maxwidth = 50, -- change this value as you want
				},
				-- 	-- 边框线
				-- 	completion = cmp.config.window.bordered(),
				-- 	documentation = cmp.config.window.bordered(),
				completion = {
					winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None",
					col_offset = -3,
					side_padding = 0,
				},
			},

			-- 补全文本格式设置
			formatting = {
				fields = { "kind", "abbr", "menu" },
				format = function(entry, vim_item)
					vim_item.kind = kind_icons[vim_item.kind] or ""
					vim_item.menu = ({
						buffer = "[Buffer]",
						nvim_lsp = "[LSP]",
						path = "[PATH]",
					})[entry.source.name]
					return vim_item
				end,
			},

			-- keys
			mapping = cmp.mapping.preset.insert({
				["<C-d>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif vim.snippet.jumpable(1) then
						vim.snippet.jump(1)
					else
						fallback()
					end
				end, { "i", "s" }),
				-- And something similar for vim.snippet.jump(-1)
				["<S-Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_prev_item()
					elseif vim.snippet.jumpable(-1) then
						vim.snippet.jump(-1)
					else
						fallback()
					end
				end, { "i", "s" }),
			}),
		})
	end,
}
