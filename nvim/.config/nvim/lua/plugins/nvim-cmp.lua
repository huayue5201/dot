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
		-- https://github.com/lukas-reineke/cmp-rg
		"lukas-reineke/cmp-rg",
		-- https://github.com/hrsh7th/cmp-nvim-lsp-signature-help
		"hrsh7th/cmp-nvim-lsp-signature-help",
		-- https://github.com/onsails/lspkind.nvim
		"onsails/lspkind.nvim",
	},
	init = function()
		vim.opt.completeopt = { "menu", "menuone", "noselect" }
	end,
	config = function()
		-- 检查光标前是否有单词
		local has_words_before = function()
			local unpack = unpack or table.unpack -- 避免使用全局变量
			local line, col = unpack(vim.api.nvim_win_get_cursor(0))
			return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
		end

		-- 菜单图标
		local lspkind = require("lspkind")
		-- 设置 nvim-cmp
		local cmp = require("cmp")

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

		-- 设置补全框架
		cmp.setup({
			completion = {
				-- 触发补全的字符数
				keyword_length = 2,
			},

			-- 片段支持(neovim核心支持lsp片段功能)
			snippet = {
				expand = function(args)
					vim.snippet.expand(args.body)
				end,
			},

			-- 补全来源列表
			sources = {
				{ name = "nvim_lsp" },
				{ name = "buffer" },
				{ name = "path" },
				{
					name = "rg",
					-- Try it when you feel cmp performance is poor
					keyword_length = 3,
				},
				{ name = "nvim_lsp_signature_help" },
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
					local kind = require("lspkind").cmp_format({ mode = "symbol_text", maxwidth = 50 })(entry, vim_item)
					local strings = vim.split(kind.kind, "%s", { trimempty = true })
					kind.kind = " " .. (strings[1] or "") .. " "
					kind.menu = "    (" .. (strings[2] or "") .. ")"

					return kind
				end,
			},

			-- 快捷键设置
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
