-- https://github.com/esmuellert/vscode-diff.nvim

return {
	"esmuellert/codediff.nvim",
	event = "BufReadPost",
	cmd = "CodeDiff",
	config = function()
		require("codediff").setup({
			highlights = {
				-- 行级：接受高亮组名称或十六进制颜色（例如 "#2ea043"）
				line_insert = "DiffAdd", -- 行级插入
				line_delete = "DiffDelete", -- 行级删除

				-- 字符级：接受高亮组名称或十六进制颜色
				-- 如果指定，将覆盖 char_brightness 计算
				char_insert = nil, -- 字符级插入（nil = 自动派生）
				char_delete = nil, -- 字符级删除（nil = 自动派生）

				-- 亮度乘数（仅在 char_insert/char_delete 为 nil 时使用）
				-- nil = 基于背景自动检测（深色背景为 1.4，浅色背景为 0.92）
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
				layout = "side-by-side", -- 差异布局："side-by-side"（双窗格）或 "inline"（单窗格带虚拟行）
				disable_inlay_hints = true, -- 在差异窗口中禁用行内提示以获得更清晰的视图
				max_computation_time_ms = 5000, -- 差异计算最大时间（VSCode 默认值）
				ignore_trim_whitespace = false, -- 忽略前导/尾随空格更改（类似 diffopt+=iwhite）
				hide_merge_artifacts = false, -- 隐藏合并工具临时文件（*.orig, *.BACKUP.*, *.BASE.*, *.LOCAL.*, *.REMOTE.*）
				original_position = "left", -- 原始（旧）内容位置："left" 或 "right"
				conflict_ours_position = "right", -- 冲突视图中我们的（:2）位置："left" 或 "right"
				conflict_result_position = "center", -- "bottom"（默认）：结果在差异窗格下方，或 "center"：结果在差异窗格之间（三列）
				conflict_result_height = 30, -- 底部布局中结果窗格的高度（占总高度的百分比）
				conflict_result_width_ratio = { 1, 1, 1 }, -- 居中布局窗格的宽度比例 {左, 中, 右}（例如 {1, 2, 1} 使结果窗格更宽）
				cycle_next_hunk = true, -- 导航差异块时循环（]c/[c）：false 则在第一个/最后一个停止
				cycle_next_file = true, -- 导航文件时循环（]f/[f）：false 则在第一个/最后一个停止
				jump_to_first_change = true, -- 打开差异时自动滚动到第一个更改：false 则停留在当前行
				highlight_priority = 100, -- 行级差异高亮的优先级（增加以覆盖 LSP 高亮）
				compute_moves = true, -- 检测移动的代码块（可选加入，匹配 VSCode experimental.showMoves）
			},

			-- 资源管理器面板配置
			explorer = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40, -- 当位置为 "left" 时的宽度（列数）
				height = 15, -- 当位置为 "bottom" 时的高度（行数）
				indent_markers = true, -- 在树视图中显示缩进标记（│, ├, └）
				initial_focus = "explorer", -- 初始焦点："explorer"、"original" 或 "modified"
				icons = {
					folder_closed = "", -- Nerd Font 文件夹图标（根据需要自定义）
					folder_open = "", -- Nerd Font 打开文件夹图标
				},
				view_mode = "list", -- "list" 或 "tree"
				flatten_dirs = true, -- 在树视图中展平单子目录链
				file_filter = {
					ignore = { ".git/**", ".jj/**" }, -- 要隐藏的全局模式（例如 {"*.lock", "dist/*"}）
				},
				focus_on_select = false, -- 选择文件后跳转到修改窗格（默认：停留在资源管理器）
				visible_groups = { -- 显示哪些组（可在运行时切换）
					staged = true,
					unstaged = true,
					conflicts = true,
				},
			},

			-- 历史面板配置（用于 :CodeDiff history）
			history = {
				position = "bottom", -- "left" 或 "bottom"（默认：bottom）
				width = 40, -- 当位置为 "left" 时的宽度（列数）
				height = 15, -- 当位置为 "bottom" 时的高度（行数）
				initial_focus = "history", -- 初始焦点："history"、"original" 或 "modified"
				view_mode = "list", -- 提交下文件的 "list" 或 "tree" 视图
			},

			-- 差异视图中的键映射
			keymaps = {
				view = {
					quit = "q", -- 关闭差异标签页
					toggle_explorer = "<leader>b", -- 切换资源管理器可见性（仅限资源管理器模式）
					focus_explorer = "<leader>e", -- 聚焦资源管理器面板（仅限资源管理器模式）
					next_hunk = "]c", -- 跳转到下一个更改
					prev_hunk = "[c", -- 跳转到上一个更改
					next_file = "]f", -- 在资源管理器/历史模式下切换下一个文件
					prev_file = "[f", -- 在资源管理器/历史模式下切换上一个文件
					diff_get = "do", -- 从另一个缓冲区获取更改（类似 vimdiff）
					diff_put = "dp", -- 将更改放入另一个缓冲区（类似 vimdiff）
					open_in_prev_tab = "gf", -- 在上一个标签页中打开当前缓冲区（或在之前创建一个）
					close_on_open_in_prev_tab = false, -- 在 gf 在上一标签页打开文件后关闭 codediff 标签页
					toggle_stage = "-", -- 暂存/取消暂存当前文件（在资源管理器和差异缓冲区中有效）
					stage_hunk = "<leader>hs", -- 将光标下的差异块暂存到 git 索引
					unstage_hunk = "<leader>hu", -- 从 git 索引取消暂存光标下的差异块
					discard_hunk = "<leader>hr", -- 放弃光标下的差异块（仅限工作树）
					hunk_textobject = "ih", -- 差异块的文本对象（vih 选择，yih 复制等）
					show_help = "g?", -- 显示浮动窗口，展示可用键映射
					align_move = "gm", -- 临时对齐跨窗格的移动代码块
					toggle_layout = "t", -- 在并排和内联布局之间切换
				},
				explorer = {
					select = "<CR>", -- 打开选中文件的差异视图
					hover = "K", -- 显示文件差异预览
					refresh = "R", -- 刷新 git 状态
					toggle_view_mode = "i", -- 在 'list' 和 'tree' 视图间切换
					stage_all = "S", -- 暂存所有文件
					unstage_all = "U", -- 取消暂存所有文件
					restore = "X", -- 放弃更改（恢复文件）
					toggle_changes = "gu", -- 切换 Changes（未暂存）组的可见性
					toggle_staged = "gs", -- 切换 Staged Changes 组的可见性
					-- 折叠键映射（Vim 风格）
					fold_open = "zo", -- 打开折叠（展开当前节点）
					fold_open_recursive = "zO", -- 递归打开折叠（展开所有后代）
					fold_close = "zc", -- 关闭折叠（折叠当前节点）
					fold_close_recursive = "zC", -- 递归关闭折叠（折叠所有后代）
					fold_toggle = "za", -- 切换折叠（展开/折叠当前节点）
					fold_toggle_recursive = "zA", -- 递归切换折叠
					fold_open_all = "zR", -- 打开树中所有折叠
					fold_close_all = "zM", -- 关闭树中所有折叠
				},
				history = {
					select = "<CR>", -- 选择提交/文件或切换展开
					toggle_view_mode = "i", -- 在 'list' 和 'tree' 视图间切换
					refresh = "R", -- 刷新历史（重新获取提交）
					-- 折叠键映射（Vim 风格，仅适用于目录节点）
					fold_open = "zo", -- 打开折叠（展开当前节点）
					fold_open_recursive = "zO", -- 递归打开折叠（展开所有后代）
					fold_close = "zc", -- 关闭折叠（折叠当前节点）
					fold_close_recursive = "zC", -- 递归关闭折叠（折叠所有后代）
					fold_toggle = "za", -- 切换折叠（展开/折叠当前节点）
					fold_toggle_recursive = "zA", -- 递归切换折叠
					fold_open_all = "zR", -- 打开树中所有折叠
					fold_close_all = "zM", -- 关闭树中所有折叠
				},
				conflict = {
					accept_incoming = "<leader>ct", -- 接受传入的（他们的/左侧）更改
					accept_current = "<leader>co", -- 接受当前的（我们的/右侧）更改
					accept_both = "<leader>cb", -- 接受双方更改（传入优先）
					discard = "<leader>cx", -- 放弃双方，保留基础版本
					-- 接受全部（整个文件）- 大写版本
					accept_all_incoming = "<leader>cT", -- 接受所有传入更改
					accept_all_current = "<leader>cO", -- 接受所有当前更改
					accept_all_both = "<leader>cB", -- 接受所有双方更改
					discard_all = "<leader>cX", -- 放弃所有，重置为基础版本
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
