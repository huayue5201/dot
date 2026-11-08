-- https://github.com/stevearc/quicker.nvim

return {
	"stevearc/quicker.nvim",
	config = function()
		require("quicker").setup({
			-- 是否使用默认 quickfix buffer 的选项
			use_default_opts = true,
			-- 编辑 quickfix buffer 的支持
			edit = {
				enabled = true,
				autosave = "unmodified", -- 保存未修改的 buffers
			},
			-- 高亮、语法支持
			highlight = {
				treesitter = true,
				lsp = true,
				load_buffers = false,
			},
			-- 快速跳转或者“粘”模式
			follow = {
				enabled = false,
			},
			-- 图标类型（与 lsp_ext/icons.lua 共用一套）
			type_icons = (function()
				local icons = require("lsp_ext.icons")
				return {
					E = icons.ERROR,
					W = icons.WARN,
					I = icons.INFO,
					N = icons.INFO,
					H = icons.HINT,
				}
			end)(),
			-- 边框字符
			borders = {
				vert = "┃",
				strong_header = "━",
				strong_cross = "╋",
				strong_end = "┫",
				soft_header = "╌",
				soft_cross = "╂",
				soft_end = "┨",
			},
			trim_leading_whitespace = "common",
			max_filename_width = function()
				return math.floor(math.min(95, vim.o.columns / 2))
			end,
			header_length = function(_, start_col)
				return vim.o.columns - start_col
			end,
			-- 自定义 keymaps（在 quickfix buffer 中）
			keys = {
				{
					"zi",
					function()
						require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
					end,
					desc = "Expand quickfix context",
				},
				{
					"zc",
					function()
						require("quicker").collapse()
					end,
					desc = "Collapse quickfix context",
				},
			},
		})

		-- 切换 quickfix 窗口
		vim.keymap.set("n", "<localleader>q", function()
			require("quicker").toggle()
		end, { desc = "列表: 切换 quickfix (localfix)" })

		-- 切换 loclist 窗口
		vim.keymap.set("n", "<localleader>l", function()
			require("quicker").toggle({ loclist = true })
		end, { desc = "列表: 切换 loclist (local)" })
	end,
}
