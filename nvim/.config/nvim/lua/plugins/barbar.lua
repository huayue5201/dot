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
	version = "^1.0.0", -- optional: only update when a new 1.x version is released
	config = function()
		require("barbar").setup({
			-- 警告：不要将下面的所有内容复制到你的配置中！
			--       这只是一个展示有哪些配置选项的例子。
			--       默认配置对大多数人来说已经足够。

			-- 启用/禁用动画效果
			animation = true,

			-- 当缓冲区数量减少到此数值时自动隐藏标签栏。
			-- 设置为 >=0 的任意值以启用。
			auto_hide = false,

			-- 启用/禁用当前/总标签页指示器（右上角）
			tabpages = true,

			-- 启用/禁用可点击的标签
			--  - 左键单击：跳转到缓冲区
			--  - 中键单击：删除缓冲区
			clickable = true,

			-- 从标签栏中排除特定文件类型的缓冲区
			-- exclude_ft = { "dap-view-term" },
			-- exclude_name = { "package.json" },

			-- 关闭当前缓冲区时，焦点将移动到该方向的缓冲区（如果存在）。
			-- 有效选项为 'left'（默认）、'previous' 和 'right'
			focus_on_close = "left",

			-- 隐藏非活动缓冲区和文件扩展名。其他选项为 `alternate`、`current` 和 `visible`
			-- hide = { extensions = true, inactive = true },

			-- 禁用备用缓冲区的高亮显示
			highlight_alternate = false,

			-- 禁用非活动缓冲区中文件图标的高亮显示
			highlight_inactive_file_icons = false,

			-- 启用可见缓冲区的高亮显示
			highlight_visible = true,

			icons = {
				-- 配置缓冲区栏上的基础图标。
				-- 显示缓冲区索引和编号的有效选项为 `true`、'superscript' 和 'subscript'
				buffer_index = false,
				buffer_number = false,
				button = "",
				-- 启用/禁用诊断符号
				diagnostics = {
					[vim.diagnostic.severity.ERROR] = { enabled = true, icon = " " },
					[vim.diagnostic.severity.WARN] = { enabled = false },
					[vim.diagnostic.severity.INFO] = { enabled = false },
					[vim.diagnostic.severity.HINT] = { enabled = true },
				},
				gitsigns = {
					added = { enabled = false, icon = "+" },
					changed = { enabled = false, icon = "~" },
					deleted = { enabled = false, icon = "-" },
				},
				filetype = {
					-- 设置图标的高亮组。
					-- 如果为 false，将使用 nvim-web-devicons 的颜色
					custom_colors = false,

					-- 如果为 `true`，则需要 `nvim-web-devicons`
					enabled = true,
				},
				separator = { left = "▎", right = "" },

				-- 如果为 true，在缓冲区列表末尾添加额外的分隔符
				separator_at_end = true,

				-- 配置缓冲区修改或固定时的图标。
				-- 支持所有基础图标选项。
				modified = { button = "●" },
				pinned = { button = "", filename = true },

				-- 使用预配置的缓冲区外观——可选 'default'、'powerline' 或 'slanted'
				preset = "default",

				-- 根据缓冲区的可见性配置图标。
				-- 支持所有基础图标选项，以及 `modified` 和 `pinned`
				alternate = { filetype = { enabled = false } },
				current = { buffer_index = true },
				inactive = { button = "×" },
				visible = { modified = { buffer_number = false } },
			},

			-- 如果为 true，新缓冲区将插入到列表的起始/结束位置。
			-- 默认为在当前缓冲区之后插入。
			insert_at_end = false,
			insert_at_start = false,

			-- 设置每个标签周围的最大内边距宽度
			maximum_padding = 1,

			-- 设置每个标签周围的最小内边距宽度
			minimum_padding = 1,

			-- 设置最大缓冲区名称长度
			maximum_length = 20,

			-- 设置最小缓冲区名称长度
			minimum_length = 0,

			-- 如果设置，缓冲区选择模式中各缓冲区的字母将基于其名称分配。
			-- 否则，或者当所有字母已被分配时，行为是按可用性顺序分配字母（参见下面的顺序）
			semantic_letters = true,

			-- 设置 barbar 将为其自身偏移的文件类型（用于侧边栏）
			sidebar_filetypes = {
				-- 使用默认值：{event = 'BufWinLeave', text = '', align = 'left'}
				-- NvimTree = true,
				-- 或者，指定偏移使用的文本：
				-- undotree = {
				-- 	text = "undotree",
				-- 	align = "center", -- *可选* 指定对齐方式（'left'、'center' 或 'right'）
				-- },
				-- 或者，指定侧边栏退出时执行的事件：
				["neo-tree"] = { event = "BufWipeout", text = "File", align = "left" },
				-- 或者，同时指定所有三个选项
				-- Outline = { event = "BufWinLeave", text = "symbols-outline", align = "right" },
			},

			-- 新缓冲区字母按此顺序分配。此顺序
			-- 对 qwerty 键盘布局是最佳的，但可能需要调整
			-- 以适应其他键盘布局。
			letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",

			-- 设置未命名缓冲区的名称。默认格式为 "[Buffer X]"
			-- 其中 X 是缓冲区编号。但此处只接受静态字符串。
			no_name_title = nil,

			-- 排序选项
			sort = {
				-- 指示 barbar 在排序缓冲区时忽略大小写差异
				ignore_case = true,
			},
		})
		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		-- Move to previous/next
		map("n", "<A-,>", "<Cmd>BufferPrevious<CR>", vim.tbl_extend("force", opts, { desc = "上一个缓冲区" }))
		map("n", "<A-.>", "<Cmd>BufferNext<CR>", vim.tbl_extend("force", opts, { desc = "下一个缓冲区" }))

		-- Re-order to previous/next
		map(
			"n",
			"<A-<>",
			"<Cmd>BufferMovePrevious<CR>",
			vim.tbl_extend("force", opts, { desc = "向左移动缓冲区" })
		)
		map("n", "<A->>", "<Cmd>BufferMoveNext<CR>", vim.tbl_extend("force", opts, { desc = "向右移动缓冲区" }))

		-- Goto buffer in position...
		map("n", "g1", "<Cmd>BufferGoto 1<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 1" }))
		map("n", "g2", "<Cmd>BufferGoto 2<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 2" }))
		map("n", "g3", "<Cmd>BufferGoto 3<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 3" }))
		map("n", "g4", "<Cmd>BufferGoto 4<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 4" }))
		map("n", "g5", "<Cmd>BufferGoto 5<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 5" }))
		map("n", "g6", "<Cmd>BufferGoto 6<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 6" }))
		map("n", "g7", "<Cmd>BufferGoto 7<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 7" }))
		map("n", "g8", "<Cmd>BufferGoto 8<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 8" }))
		map("n", "g9", "<Cmd>BufferGoto 9<CR>", vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 9" }))
		map(
			"n",
			"g0",
			"<Cmd>BufferLast<CR>",
			vim.tbl_extend("force", opts, { desc = "跳转到最后一个缓冲区" })
		)

		-- Pin/unpin buffer
		map(
			"n",
			"<A-p>",
			"<Cmd>BufferPin<CR>",
			vim.tbl_extend("force", opts, { desc = "固定/取消固定当前缓冲区" })
		)

		-- Goto pinned/unpinned buffer
		-- 如果需要取消注释，可以添加：
		-- map('n', '<leader>bp', '<Cmd>BufferGotoPinned<CR>', vim.tbl_extend('force', opts, { desc = '跳转到固定缓冲区' }))
		-- map('n', '<leader>bu', '<Cmd>BufferGotoUnpinned<CR>', vim.tbl_extend('force', opts, { desc = '跳转到未固定缓冲区' }))

		-- Close buffer
		map("n", "<A-c>", "<Cmd>BufferClose<CR>", vim.tbl_extend("force", opts, { desc = "关闭当前缓冲区" }))

		-- Wipeout buffer
		-- 如果需要取消注释，可以添加：
		-- map('n', '<leader>bw', '<Cmd>BufferWipeout<CR>', vim.tbl_extend('force', opts, { desc = '彻底删除当前缓冲区' }))

		-- Close commands
		-- 如果需要取消注释，可以添加：
		-- map('n', '<leader>bca', '<Cmd>BufferCloseAllButCurrent<CR>', vim.tbl_extend('force', opts, { desc = '关闭除当前外所有缓冲区' }))
		-- map('n', '<leader>bcp', '<Cmd>BufferCloseAllButPinned<CR>', vim.tbl_extend('force', opts, { desc = '关闭除固定外所有缓冲区' }))
		-- map('n', '<leader>bco', '<Cmd>BufferCloseAllButCurrentOrPinned<CR>', vim.tbl_extend('force', opts, { desc = '关闭除当前或固定外所有缓冲区' }))
		-- map('n', '<leader>bcl', '<Cmd>BufferCloseBuffersLeft<CR>', vim.tbl_extend('force', opts, { desc = '关闭左侧所有缓冲区' }))
		-- map('n', '<leader>bcr', '<Cmd>BufferCloseBuffersRight<CR>', vim.tbl_extend('force', opts, { desc = '关闭右侧所有缓冲区' }))

		-- Magic buffer-picking mode
		map("n", "<C-p>", "<Cmd>BufferPick<CR>", vim.tbl_extend("force", opts, { desc = "缓冲区选择模式" }))
		map(
			"n",
			"<C-s-p>",
			"<Cmd>BufferPickDelete<CR>",
			vim.tbl_extend("force", opts, { desc = "缓冲区选择删除模式" })
		)

		-- Sort automatically by...
		map(
			"n",
			"gbbb",
			"<Cmd>BufferOrderByBufferNumber<CR>",
			vim.tbl_extend("force", opts, { desc = "按缓冲区编号排序" })
		)
		map("n", "gbbn", "<Cmd>BufferOrderByName<CR>", vim.tbl_extend("force", opts, { desc = "按名称排序" }))
		map("n", "gbbd", "<Cmd>BufferOrderByDirectory<CR>", vim.tbl_extend("force", opts, { desc = "按目录排序" }))
		map("n", "gbbl", "<Cmd>BufferOrderByLanguage<CR>", vim.tbl_extend("force", opts, { desc = "按语言排序" }))
		map(
			"n",
			"gbbw",
			"<Cmd>BufferOrderByWindowNumber<CR>",
			vim.tbl_extend("force", opts, { desc = "按窗口编号排序" })
		)

		-- Other:
		-- :BarbarEnable - enables barbar (enabled by default)
		-- :BarbarDisable - very bad command, should never be used
	end,
}
