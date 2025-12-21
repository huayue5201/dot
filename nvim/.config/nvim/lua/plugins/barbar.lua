-- https://github.com/romgrk/barbar.nvim

return {
	"romgrk/barbar.nvim",
	dependencies = {
		"lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
		"nvim-tree/nvim-web-devicons", -- OPTIONAL: for file icons
	},
	init = function()
		vim.g.barbar_auto_setup = false
	end,
	config = function()
		require("barbar").setup({

			-- 排除的文件类型，不显示在标签栏
			-- exclude_ft = { "javascript" },
			-- exclude_name = { "package.json" },

			icons = {
				-- 配置缓冲区行上的基本图标。
				-- 有效选项用于显示缓冲区索引和编号为 `true`、`superscript` 或 `subscript`
				buffer_index = false,
				buffer_number = false,
				button = "",
				-- 启用/禁用诊断符号
				diagnostics = {
					[vim.diagnostic.severity.ERROR] = { enabled = true, icon = "ﬀ" },
					[vim.diagnostic.severity.WARN] = { enabled = false },
					[vim.diagnostic.severity.INFO] = { enabled = false },
					[vim.diagnostic.severity.HINT] = { enabled = true },
				},
				gitsigns = {
					added = { enabled = true, icon = "+" },
					changed = { enabled = true, icon = "~" },
					deleted = { enabled = true, icon = "-" },
				},
				filetype = {
					-- 设置图标的高亮组。
					-- 如果设置为 false，则使用 nvim-web-devicons 的颜色
					custom_colors = false,

					-- 如果设置为 true，则需要 `nvim-web-devicons`
					enabled = true,
				},
				separator = { left = "▎", right = "" },

				-- 如果为 true，缓冲区列表末尾将添加一个额外的分隔符
				separator_at_end = true,

				-- 配置缓冲区行上的图标，修改或固定的缓冲区。
				-- 支持所有基本图标选项。
				modified = { button = "●" },
				pinned = { button = "", filename = true },

				-- 使用预配置的缓冲区外观，可以是 'default'、'powerline' 或 'slanted'
				preset = "default",

				-- 根据缓冲区的可见性配置图标。
				-- 支持所有基本图标选项，还包括 `modified` 和 `pinned`。
				alternate = { filetype = { enabled = false } },
				current = { buffer_index = true },
				inactive = { button = "×" },
				visible = { modified = { buffer_number = false } },
			},

			-- 设置 barbar 插件将为以下文件类型添加偏移量
			sidebar_filetypes = {
				-- 使用默认值：{event = 'BufWinLeave', text = '', align = 'left'}
				NvimTree = true,
				-- 或指定缓冲区离开时触发的事件：
				["neo-tree"] = { event = "BufWipeout" },
			},

			-- 新缓冲区字母按照以下顺序分配。这个顺序对于 qwerty 键盘布局是最优的，但对于其他布局可能需要调整。
			letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",
		})

		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		-- Move to previous/next
		map("n", "<A-,>", "<Cmd>BufferPrevious<CR>", opts)
		map("n", "<A-.>", "<Cmd>BufferNext<CR>", opts)

		-- Re-order to previous/next
		map("n", "<A-<>", "<Cmd>BufferMovePrevious<CR>", opts)
		map("n", "<A->>", "<Cmd>BufferMoveNext<CR>", opts)

		-- Goto buffer in position...
		map("n", "<A-1>", "<Cmd>BufferGoto 1<CR>", opts)
		map("n", "<A-2>", "<Cmd>BufferGoto 2<CR>", opts)
		map("n", "<A-3>", "<Cmd>BufferGoto 3<CR>", opts)
		map("n", "<A-4>", "<Cmd>BufferGoto 4<CR>", opts)
		map("n", "<A-5>", "<Cmd>BufferGoto 5<CR>", opts)
		map("n", "<A-6>", "<Cmd>BufferGoto 6<CR>", opts)
		map("n", "<A-7>", "<Cmd>BufferGoto 7<CR>", opts)
		map("n", "<A-8>", "<Cmd>BufferGoto 8<CR>", opts)
		map("n", "<A-9>", "<Cmd>BufferGoto 9<CR>", opts)
		map("n", "<A-0>", "<Cmd>BufferLast<CR>", opts)

		-- Pin/unpin buffer
		map("n", "<A-p>", "<Cmd>BufferPin<CR>", opts)

		-- Goto pinned/unpinned buffer
		--                 :BufferGotoPinned
		--                 :BufferGotoUnpinned

		-- Close buffer
		map("n", "<A-c>", "<Cmd>BufferClose<CR>", opts)

		-- Wipeout buffer
		--                 :BufferWipeout

		-- Close commands
		--                 :BufferCloseAllButCurrent
		--                 :BufferCloseAllButPinned
		--                 :BufferCloseAllButCurrentOrPinned
		--                 :BufferCloseBuffersLeft
		--                 :BufferCloseBuffersRight

		-- Magic buffer-picking mode
		map("n", "<C-p>", "<Cmd>BufferPick<CR>", opts)
		map("n", "<C-s-p>", "<Cmd>BufferPickDelete<CR>", opts)

		-- Sort automatically by...
		map("n", "<localleader>bb", "<Cmd>BufferOrderByBufferNumber<CR>", opts)
		map("n", "<localleader>bn", "<Cmd>BufferOrderByName<CR>", opts)
		map("n", "<localleader>bd", "<Cmd>BufferOrderByDirectory<CR>", opts)
		map("n", "<localleader>bl", "<Cmd>BufferOrderByLanguage<CR>", opts)
		map("n", "<localleader>bw", "<Cmd>BufferOrderByWindowNumber<CR>", opts)

		-- Other:
		-- :BarbarEnable - enables barbar (enabled by default)
		-- :BarbarDisable - very bad command, should never be used
	end,
}
