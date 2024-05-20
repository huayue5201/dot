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
		-- https://github.com/ray-x/cmp-treesitter
		"ray-x/cmp-treesitter",
	},
	init = function()
		vim.opt.completeopt = { "menu", "menuone", "noselect" }
	end,
	config = function()
		-- 高亮显示组设置
		local highlight_groups = {
			PmenuSel = { bg = "#282C34", fg = "NONE" },
			Pmenu = { fg = "#C5CDD9", bg = "#22252A" },
			CmpItemAbbrDeprecated = { fg = "#7E8294", bg = "NONE", strikethrough = true },
			CmpItemAbbrMatch = { fg = "#82AAFF", bg = "NONE", bold = true },
			CmpItemAbbrMatchFuzzy = { fg = "#82AAFF", bg = "NONE", bold = true },
			CmpItemMenu = { fg = "#C792EA", bg = "NONE", italic = true },
			CmpItemKindField = { fg = "#EED8DA", bg = "#FF0088" },
			CmpItemKindProperty = { fg = "#EED8DA", bg = "#FF0088" },
			CmpItemKindEvent = { fg = "#EED8DA", bg = "#FF0088" },
			CmpItemKindText = { fg = "#C3E88D", bg = "#00A400" },
			CmpItemKindEnum = { fg = "#C3E88D", bg = "#00A400" },
			CmpItemKindKeyword = { fg = "#C3E88D", bg = "#00A400" },
			CmpItemKindConstant = { fg = "#FFE082", bg = "#009FCC" },
			CmpItemKindConstructor = { fg = "#FFE082", bg = "#009FCC" },
			CmpItemKindReference = { fg = "#FFE082", bg = "#009FCC" },
			CmpItemKindFunction = { fg = "#EADFF0", bg = "#660077" },
			CmpItemKindStruct = { fg = "#EADFF0", bg = "#660077" },
			CmpItemKindClass = { fg = "#EADFF0", bg = "#660077" },
			CmpItemKindModule = { fg = "#EADFF0", bg = "#660077" },
			CmpItemKindOperator = { fg = "#EADFF0", bg = "#660077" },
			CmpItemKindVariable = { fg = "#C5CDD9", bg = "#7E8294" },
			CmpItemKindFile = { fg = "#C5CDD9", bg = "#7E8294" },
			CmpItemKindUnit = { fg = "#F5EBD9", bg = "#EE7700" },
			CmpItemKindSnippet = { fg = "#F5EBD9", bg = "#EE7700" },
			CmpItemKindFolder = { fg = "#F5EBD9", bg = "#EE7700" },
			CmpItemKindMethod = { fg = "#DDE5F5", bg = "#6C8ED4" },
			CmpItemKindValue = { fg = "#DDE5F5", bg = "#6C8ED4" },
			CmpItemKindEnumMember = { fg = "#DDE5F5", bg = "#6C8ED4" },
			CmpItemKindInterface = { fg = "#D8EEEB", bg = "#58B5A8" },
			CmpItemKindColor = { fg = "#D8EEEB", bg = "#58B5A8" },
			CmpItemKindTypeParameter = { fg = "#D8EEEB", bg = "#58B5A8" },
		}
		-- 循环设置高亮显示组
		for group, attrs in pairs(highlight_groups) do
			vim.api.nvim_set_hl(0, group, attrs)
		end

		-- 图标
		local cmp_kinds = {
			Text = "   ",
			Method = "   ",
			Function = "   ",
			Constructor = "   ",
			Field = "   ",
			Variable = "   ",
			Class = "   ",
			Interface = "   ",
			Module = "   ",
			Property = "   ",
			Unit = "   ",
			Value = "   ",
			Enum = "   ",
			Keyword = "   ",
			Snippet = "   ",
			Color = "   ",
			File = "   ",
			Reference = "   ",
			Folder = "   ",
			EnumMember = "   ",
			Constant = "   ",
			Struct = "   ",
			Event = "   ",
			Operator = "   ",
			TypeParameter = "   ",
		}

		-- 设置 nvim-cmp
		local cmp = require("cmp")

		-- 设置补全框架
		cmp.setup({
			-- 片段支持(neovim核心支持lsp片段功能)
			snippet = {
				expand = function(args)
					vim.snippet.expand(args.body)
				end,
			},

			-- 补全来源列表
			sources = {
				{ name = "nvim_lsp", keyword_length = 2 },
				{ name = "buffer" },
				{ name = "path" },
				{ name = "nvim_lsp_signature_help" },
				{ name = "treesitter" },
			},

			-- 补全弹窗设置
			window = {
				-- nvim_lsp_signature_help弹窗大小
				documentation = {
					maxheight = 15,
					maxwidth = 50, -- 根据需要调整这个值
				},
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
					vim_item.kind = cmp_kinds[vim_item.kind] or ""
					vim_item.menu = ({
						buffer = "[Buffer]",
						nvim_lsp = "[LSP]",
						path = "[PATH]",
						treesitter = "[Treesitter]",
					})[entry.source.name]
					return vim_item
				end,
			},

			-- 快捷键设置
			mapping = cmp.mapping.preset.insert({
				["<C-d>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				["<C-Space>"] = cmp.mapping.complete(),
				["<CR>"] = cmp.mapping({
					i = function(fallback)
						if cmp.visible() and cmp.get_active_entry() then
							cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
						else
							fallback()
						end
					end,
					s = cmp.mapping.confirm({ select = true }),
					c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
				}),
				["<Tab>"] = cmp.mapping(function(fallback)
					if cmp.visible() then
						cmp.select_next_item()
					elseif vim.snippet.jumpable(1) then
						vim.snippet.jump(1)
					else
						fallback()
					end
				end, { "i", "s" }),
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
