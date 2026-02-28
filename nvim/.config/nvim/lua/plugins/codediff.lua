-- https://github.com/esmuellert/vscode-diff.nvim

return {
	"esmuellert/codediff.nvim",
	event = "BufReadPost",
	cmd = "CodeDiff",
	config = function()
		require("codediff").setup({
			-- 高亮配置
			highlights = {
				-- 行级别：接受高亮组名称或十六进制颜色（例如 "#2ea043"）
				line_insert = "DiffAdd", -- 行级别的插入
				line_delete = "DiffDelete", -- 行级别的删除

				-- 字符级别：接受高亮组名称或十六进制颜色
				-- 如果指定，这些会覆盖 char_brightness 的计算
				char_insert = nil, -- 字符级别的插入（nil = 自动推导）
				char_delete = nil, -- 字符级别的删除（nil = 自动推导）

				-- 亮度乘数（仅在 char_insert/char_delete 为 nil 时使用）
				-- nil = 根据背景自动检测（暗色主题用1.4，亮色主题用0.92）
				char_brightness = nil, -- 根据你的颜色方案自动调整

				-- 冲突标记高亮（用于合并冲突视图）
				-- 接受高亮组名称或十六进制颜色（例如 "#f0883e"）
				-- nil = 使用默认的回退链
				conflict_sign = nil, -- 未解决：DiagnosticSignWarn -> #f0883e
				conflict_sign_resolved = nil, -- 已解决：Comment -> #6e7681
				conflict_sign_accepted = nil, -- 已接受：GitSignsAdd -> DiagnosticSignOk -> #3fb950
				conflict_sign_rejected = nil, -- 已拒绝：GitSignsDelete -> DiagnosticSignError -> #f85149
			},

			-- 差异视图行为
			diff = {
				layout = "inline", -- 差异布局："side-by-side"（双面板）或 "inline"（单面板+虚拟行）
				disable_inlay_hints = true, -- 在差异窗口中禁用内联提示以获得更清晰的视图
				max_computation_time_ms = 5000, -- 差异计算的最大时间（VSCode 默认值）
				ignore_trim_whitespace = false, -- 忽略行首/行尾的空白字符变化（类似 diffopt+=iwhite）
				hide_merge_artifacts = false, -- 隐藏合并工具临时文件（*.orig, *.BACKUP.*, *.BASE.*, *.LOCAL.*, *.REMOTE.*）
				original_position = "left", -- 原始（旧）内容的位置："left" 或 "right"
				conflict_ours_position = "right", -- 冲突视图中我们方（:2）的位置："left" 或 "right"
				conflict_result_position = "bottom", -- "bottom"（默认）：结果面板在差异面板下方；"center"：结果面板在差异面板中间（三列）
				conflict_result_height = 30, -- bottom 布局下结果面板的高度（占总高度的百分比）
				conflict_result_width_ratio = { 1, 1, 1 }, -- center 布局下面板的宽度比例 {左, 中, 右}（例如 {1,2,1} 让结果面板更宽）
				cycle_next_hunk = true, -- 导航差异块（]c/[c）时是否循环：false 表示停在第一个/最后一个
				cycle_next_file = true, -- 导航文件（]f/[f）时是否循环：false 表示停在第一个/最后一个
				jump_to_first_change = true, -- 打开差异时是否自动滚动到第一个变更：false 表示停在当前行
				highlight_priority = 100, -- 行级别差异高亮的优先级（增大值可覆盖 LSP 高亮）
			},

			-- 资源管理器面板配置
			explorer = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40, -- 位置为 "left" 时的宽度（列数）
				height = 15, -- 位置为 "bottom" 时的高度（行数）
				indent_markers = true, -- 在树形视图中显示缩进标记（│, ├, └）
				initial_focus = "explorer", -- 初始焦点："explorer"、"original" 或 "modified"
				icons = {
					folder_closed = "", -- Nerd Font 文件夹图标（根据需要自定义）
					folder_open = "", -- Nerd Font 打开文件夹图标
				},
				view_mode = "list", -- "list" 或 "tree"
				flatten_dirs = true, -- 在树形视图中展平只有单个子项的目录链
				file_filter = {
					ignore = {}, -- 要隐藏的全局模式（例如 {"*.lock", "dist/*"}）
				},
				focus_on_select = false, -- 选中文件后是否跳转到修改后面板（默认：停留在资源管理器）
				visible_groups = { -- 要显示的文件分组（运行时可切换）
					staged = true,
					unstaged = true,
					conflicts = true,
				},
			},

			-- 历史记录面板配置（用于 :CodeDiff history）
			history = {
				position = "bottom", -- "left" 或 "bottom"（默认：bottom）
				width = 40, -- 位置为 "left" 时的宽度（列数）
				height = 15, -- 位置为 "bottom" 时的高度（行数）
				initial_focus = "history", -- 初始焦点："history"、"original" 或 "modified"
				view_mode = "list", -- 提交下文件的视图模式："list" 或 "tree"
			},

			-- 差异视图中的按键映射
			keymaps = {
				view = {
					quit = "q", -- 关闭差异标签页
					toggle_explorer = "<leader>b", -- 切换资源管理器可见性（仅限资源管理器模式）
					focus_explorer = "<leader>e", -- 聚焦到资源管理器面板（仅资源管理器模式）
					next_hunk = "]c", -- 跳转到下一个更改
					prev_hunk = "[c", -- 跳转到上一个更改
					next_file = "]f", -- 资源管理器模式中的下一个文件
					prev_file = "[f", -- 资源管理器模式中的上一个文件
					diff_get = "do", -- 从另一个缓冲区获取更改（类似 vimdiff）
					diff_put = "dp", -- 将更改放入另一个缓冲区（类似 vimdiff）
					open_in_prev_tab = "gf", -- 在之前的标签页打开当前缓冲区（若无则新建）
					close_on_open_in_prev_tab = false, -- 执行 gf 后关闭 codediff 标签页
					toggle_stage = "-", -- 暂存/取消暂存当前文件（资源管理器和差异缓冲区均生效）
					stage_hunk = "<leader>hs", -- 将光标下的差异块暂存到 git 索引
					unstage_hunk = "<leader>hu", -- 将光标下的差异块从 git 索引取消暂存
					discard_hunk = "<leader>hr", -- 放弃光标下的差异块（仅工作区）
					hunk_textobject = "ih", -- 差异块的文本对象（vih 选中，yih 复制等）
					show_help = "g?", -- 显示浮动窗口，展示所有可用快捷键
				},
				explorer = {
					select = "<CR>", -- 打开选中文件的差异
					hover = "K", -- 显示文件差异预览
					refresh = "R", -- 刷新 git 状态
					toggle_view_mode = "i", -- 在 'list' 和 'tree' 视图之间切换
					toggle_stage = "-", -- 暂存/取消暂存选中的文件
					stage_all = "S", -- 暂存所有文件
					unstage_all = "U", -- 取消暂存所有文件
					restore = "X", -- 丢弃更改（恢复文件）
					toggle_changes = "gu", -- 切换「变更（未暂存）」分组的可见性
					toggle_staged = "gs", -- 切换「已暂存变更」分组的可见性
				},
				history = {
					select = "<CR>", -- 选择提交/文件或切换展开状态
					toggle_view_mode = "i", -- 在 'list' 和 'tree' 视图之间切换
				},
				conflict = {
					accept_incoming = "<leader>ct", -- 接受传入的（他们的/左侧）更改
					accept_current = "<leader>co", -- 接受当前的（我们的/右侧）更改
					accept_both = "<leader>cb", -- 接受双方更改（先传入的）
					discard = "<leader>cx", -- 丢弃双方，保留基础版本
					next_conflict = "]x", -- 跳转到下一个冲突
					prev_conflict = "[x", -- 跳转到上一个冲突
					diffget_incoming = "2do", -- 从传入（左侧/他们的）缓冲区获取差异块
					diffget_current = "3do", -- 从当前（右侧/我们的）缓冲区获取差异块
				},
			},
		})
		vim.keymap.set("n", "<leader>hf", "<cmd>CodeDiff<cr>", { desc = "codediff: Diff" })
		vim.keymap.set("n", "<leader>hh", "<cmd>CodeDiff history<cr>", { desc = "codediff: history" })
	end,
}
