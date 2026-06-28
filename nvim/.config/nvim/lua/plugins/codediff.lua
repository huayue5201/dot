-- https://github.com/esmuellert/codediff.nvim

return {
	"esmuellert/codediff.nvim",
	event = "VeryLazy",
	cmd = "CodeDiff",
	config = function()
		require("codediff").setup({
			-- 高亮配置
			highlights = {
				line_insert = "DiffAdd",
				line_delete = "DiffDelete",
				char_insert = nil, -- 自动派生
				char_delete = nil, -- 自动派生
				char_brightness = nil, -- 自动检测（深色主题1.4，浅色0.92）
				conflict_sign = nil,
				conflict_sign_resolved = nil,
				conflict_sign_accepted = nil,
				conflict_sign_rejected = nil,
			},

			-- 差异视图行为
			diff = {
				layout = "side-by-side", -- "side-by-side" 或 "inline"
				disable_inlay_hints = true, -- 禁用内联提示
				max_computation_time_ms = 5000, -- 最大计算时间
				ignore_trim_whitespace = false, -- 是否忽略空白字符
				hide_merge_artifacts = false, -- 隐藏合并工具临时文件
				conflict_result_position = "bottom", -- "bottom" 或 "center"
				conflict_result_height = 30, -- 底部布局结果窗格高度
				conflict_result_width_ratio = { 1, 1, 1 }, -- 居中布局宽度比例
				cycle_hunks_across_files = true, -- 导航 hunk 时循环文件（原 cycle_next_hunk）
				jump_to_first_change = true, -- 自动跳转到第一个更改
				highlight_priority = 100, -- 高亮优先级
				compute_moves = true, -- 检测移动的代码块（VSCode 风格）
				compact_context_lines = 3, -- 紧凑模式上下文行数
				compact_sync_folds = true, -- 同步折叠状态
			},

			-- 资源管理器面板配置
			explorer = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40, -- 左侧布局宽度
				height = 15, -- 底部布局高度
				hidden = false, -- 是否显示隐藏文件
				auto_refresh = true, -- 自动刷新 git 状态
				auto_open_on_cursor = false, -- 光标移动时自动打开
				indent_markers = true, -- 显示缩进标记
				initial_focus = "explorer", -- 初始焦点："explorer", "original", "modified"
				view_mode = "tree", -- "list" 或 "tree"
				flatten_dirs = true, -- 展平单子目录链
				focus_on_select = false, -- 选择后是否聚焦修改窗格
				status_right_margin = 1, -- 状态右侧边距
				icons = {
					folder_closed = "",
					folder_open = "",
				},
				file_filter = {
					ignore = { ".git/**", ".jj/**", "node_modules/**", "dist/**", ".cache/**" },
				},
				visible_groups = {
					staged = true,
					unstaged = true,
					conflicts = true,
				},
			},

			-- 历史面板配置
			history = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40,
				height = 15,
				initial_focus = "history",
				view_mode = "list",
			},

			-- 键映射配置
			keymaps = {
				view = {
					quit = "q",
					toggle_explorer = "<leader>b",
					focus_explorer = "<leader>e",
					next_hunk = "]c",
					prev_hunk = "[c",
					next_file = "]f",
					prev_file = "[f",
					diff_get = "do",
					diff_put = "dp",
					open_in_prev_tab = "gf",
					close_on_open_in_prev_tab = false,
					toggle_stage = "-",
					hunk_textobject = "ih",
					show_help = "g?",
					align_move = "gm",
					toggle_layout = "t",
					toggle_compact = "gc",
				},
				explorer = {
					select = "<CR>",
					hover = "K",
					refresh = "R",
					toggle_view_mode = "i",
					stage_all = "S",
					unstage_all = "U",
					restore = "X",
					toggle_changes = "gu",
					toggle_staged = "gs",
					fold_open = "zo",
					fold_open_recursive = "zO",
					fold_close = "zc",
					fold_close_recursive = "zC",
					fold_toggle = "za",
					fold_toggle_recursive = "zA",
					fold_open_all = "zR",
					fold_close_all = "zM",
				},
				history = {
					select = "<CR>",
					toggle_view_mode = "i",
					refresh = "R",
					fold_open = "zo",
					fold_open_recursive = "zO",
					fold_close = "zc",
					fold_close_recursive = "zC",
					fold_toggle = "za",
					fold_toggle_recursive = "zA",
					fold_open_all = "zR",
					fold_close_all = "zM",
				},
				conflict = {
					accept_incoming = "<leader>ct",
					accept_current = "<leader>co",
					accept_both = "<leader>cb",
					discard = "<leader>cx",
					accept_all_incoming = "<leader>cT",
					accept_all_current = "<leader>cO",
					accept_all_both = "<leader>cB",
					discard_all = "<leader>cX",
					next_conflict = "]x",
					prev_conflict = "[x",
					diffget_incoming = "2do",
					diffget_current = "3do",
				},
			},
		})

		-- 快捷键
		local keymap = vim.keymap.set
		local opts = { noremap = true, silent = true }

		keymap(
			"n",
			"<leader>hf",
			"<cmd>CodeDiff<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Git diff explorer" })
		)
		keymap(
			"n",
			"<leader>hh",
			"<cmd>CodeDiff history<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Repository history" })
		)
		keymap(
			"n",
			"<leader>hd",
			"<cmd>CodeDiff % HEAD<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Diff current file with HEAD" })
		)
		keymap(
			"n",
			"<leader>hH",
			"<cmd>CodeDiff history %<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: History of current file" })
		)
		keymap(
			"v",
			"<leader>hh",
			"<cmd>CodeDiff history<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Line range history" })
		)
	end,
}
