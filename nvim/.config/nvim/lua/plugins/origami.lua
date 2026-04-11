-- https://github.com/chrisgrieser/nvim-origami

-- lazy.nvim
return {
	"chrisgrieser/nvim-origami",
	event = "VeryLazy",
	config = function()
		-- default settings
		-- 默认配置
		require("origami").setup({
			-- 使用 LSP 折叠，若 LSP 不支持则回退到 Treesitter
			useLspFoldsWithTreesitterFallback = {
				enabled = true, -- 启用 LSP + Treesitter 折叠策略
				-- 如果 LSP 和 Treesitter 都不可用，则使用此 foldmethod
				foldmethodIfNeitherIsAvailable = "indent", ---@type string|fun(bufnr: number): string
			},

			-- 搜索时暂停折叠（避免搜索结果被折叠挡住）
			pauseFoldsOnSearch = true,

			-- 自定义 foldtext（折叠行显示内容）
			foldtext = {
				enabled = true, -- 启用自定义 foldtext

				-- 折叠行左侧的 padding（空白）
				padding = {
					character = " ", -- 填充字符
					width = 3, -- 填充宽度，可以是数字或函数
					hlgroup = nil, -- 高亮组（nil = 默认）
				},

				-- 折叠行右侧显示“多少行被折叠”
				lineCount = {
					template = "%d lines", -- `%d` 会替换为折叠的行数
					hlgroup = "Comment", -- 使用 Comment 高亮
				},

				-- 是否显示诊断数量（需要 vim.diagnostic）
				diagnosticsCount = true,

				-- 是否显示 gitsigns 的修改数量（需要 gitsigns.nvim）
				gitsignsCount = true,

				-- 在这些 filetype 下禁用 foldtext
				disableOnFt = { "snacks_picker_input" }, ---@type string[]
			},

			-- 自动折叠功能
			autoFold = {
				enabled = false, -- 启用自动折叠
				kinds = { "comment", "imports" }, -- 自动折叠的 LSP FoldingRangeKind 类型
				-- 常见 kinds:
				-- "comment"  → 折叠注释块
				-- "imports"  → 折叠 import / use / require 区域
			},

			-- 折叠相关的键位增强
			foldKeymaps = {
				setup = true, -- 是否修改 h / l / ^ / $ 的行为（更智能的折叠导航）

				-- h 和 ^ 是否只在第一列触发折叠
				closeOnlyOnFirstColumn = false,

				-- ^ 是否自动滚动到行首（类似 0^）
				scrollLeftOnCaret = false,
			},
		})

		vim.keymap.set("n", "<Left>", function()
			require("origami").h()
		end)
		vim.keymap.set("n", "<Right>", function()
			require("origami").l()
		end)
		vim.keymap.set("n", "<End>", function()
			require("origami").dollar()
		end)
	end,
	-- recommended: disable vim's auto-folding
	init = function()
		vim.opt.foldlevel = 99
		vim.opt.foldlevelstart = 99
	end,
}
