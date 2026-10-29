-- https://github.com/huayue5201/todo2

return {
	dir = "~/neovim-plugins/todo2",
	dependencies = { { dir = "~/neovim-plugins/nvim-store3" } },
	name = "todo2",
	-- setup 由插件端 plugin/todo2.lua 惰性触发；加载器没有 lazy 字段，无需配置
	init = function()
		-- 可选：自定义配置（以下均为顶层键，均有默认值，按需覆盖）
		vim.g.todo2_config = {
			-- 核心开关
			conceal_enable = true, -- TODO 文件 conceal 渲染（复选框图标等）

			-- 解析器行为
			parser = {
				indent_width = 2, -- 缩进宽度（空格数）
				empty_line_reset = 1, -- 空行重置
				context_split = false, -- 上下文拆分
			},

			-- 代码文件里的任务渲染（above/below 虚拟行）
			code_render = {
				-- "trunc"（默认，不随横滚）| "scroll"（nowrap 时随代码横滚）| "auto" | "wrap"
				virt_lines_overflow = "trunc",
			},

			-- 进度条样式
			progress_bar = {
				style = "full",
				chars = {
					filled = "▰",
					empty = "▱",
				},
				length = { min = 5, max = 20 },
				highlights = {
					done = "Todo2ProgressDone",
					todo = "Todo2ProgressTodo",
				},
			},

			-- 复选框图标（未完成 / 完成 / 归档）
			checkbox_icons = {
				todo = "◻",
				done = "✔",
				archived = "📦",
			},

			-- 树形缩进图标（drawer / viewer 共用）
			viewer_icons = {
				indent = {
					top = "│ ",
					middle = "├─",
					last = "└─",
					ws = "  ",
				},
			},

			-- 视图（viewer）显示配置
			viewer_show_icons = true, -- 是否显示图标
			viewer_show_child_count = true, -- 是否显示子任务计数
			viewer_file_header_style = "─ %s ──[ %d tasks ]", -- 文件 header 格式

			-- 任务树抽屉（:TodoDrawer）
			drawer = {
				position = "right", -- "right" | "bottom"（bottom 上下拆分可展示更多）
				width = 60, -- position = "right" 时的宽度
				height = 12, -- position = "bottom" 时的高度
				focus_on_jump = false, -- true 时 <CR> 跳转后焦点跟随到代码窗口
			},

			-- Git 集成（提交消息关单 / 锚点历史 / 提交前自查）
			git = {
				enable = true, -- 总开关（:TodoGitSync! 可临时绕过）
				trigger = "manual", -- "manual" | "on_open"（on_open 时打开 TODO 自动增量同步）
				show_metadata = true, -- 在查看器 / 抽屉显示关联提交
				refs = {
					-- 提交消息里出现 [Tt]odo:<id> 时把该任务标为完成
					{ pattern = "[Tt]odo[:：]%s*([0-9a-z]+)", status = "completed" },
				},
			},

			-- 归档区域标题前缀（归档任务存放于文件内 `## Archived (YYYY-MM)` 段）
			archive_section = {
				title_prefix = "## Archived",
			},

			-- 归档（归档 = 把任务行移入文件内 `## Archived (YYYY-MM)` 段，可逆；:TodoArchive / :TodoUnarchive）
			archive = {
				allow_unfinished = true, -- 是否允许归档含未完成任务的组（<leader>mA! 可强制）
				include_in_render = false, -- 抽屉初次打开时是否并入归档任务（抽屉内按 A 可切换）
				auto_after_days = 0, -- 自动归档阈值（天，0=关闭）
			},

			-- TODO 文件识别（可扩展任意格式）
			todo_files = {
				extensions = { ".todo.md", ".todo", ".todo.txt" }, -- 后缀匹配
				filenames = { "todo.txt" }, -- 精确文件名
				globs = { "*.todo.md", "*.todo", "*.todo.txt", "todo.txt" }, -- 搜索 glob
				default_ext = ".todo.md", -- 新建默认后缀
			},

			-- 新文件模板
			file_template = {
				default_content = { "## Active" },
			},
		}
	end,
	config = function()
		------------------------------------------------------------------
		-- 全局映射（插件不再提供默认 <leader>m* 映射，这里手动加入）
		-- 约定：<leader>m<组> 是纯分组前缀（本身不映射，杜绝超时歧义），
		--       具体动作一律 <leader>m<组><动作>，语义 = 组 + 动作。
		------------------------------------------------------------------
		------------------------------------------------------------------
		-- 高频动作快捷别名（平铺一层）
		-- 只取分组前缀以外的单字母：mf/mt/ma/mv/ml/mg 是分组，mp 已被 SmartPreview 用掉，
		-- 所以这里只用 mn / mc / md，不抢分组前缀（否则 maa、mvv 这类进不去）。
		-- 同一命令只在单键别名处保留一份，分组里不再重复定义。
		------------------------------------------------------------------
		vim.keymap.set("n", "<leader>mn", "<cmd>TodoNew<cr>", { desc = "TODO: 新建文件" })
		vim.keymap.set("n", "<leader>mc", "<cmd>TodoAdd<cr>", { desc = "TODO: 从代码建任务" })
		vim.keymap.set("n", "<leader>md", "<cmd>TodoDrawer<cr>", { desc = "TODO: 打开任务抽屉" })

		-- 文件（mf-）
		vim.keymap.set("n", "<leader>mfr", "<cmd>TodoRename<cr>", { desc = "重命名 TODO 文件" })
		vim.keymap.set("n", "<leader>mfd", "<cmd>TodoDelete<cr>", { desc = "删除 TODO 文件" })

		-- 任务（mt-）
		vim.keymap.set("n", "<leader>mte", "<cmd>TodoEditTask<cr>", { desc = "从代码编辑关联任务" })
		vim.keymap.set("n", "<leader>mts", "<cmd>TodoStatus<cr>", { desc = "选择任务状态" })
		vim.keymap.set("n", "<leader>mtd", "<cmd>TodoDesc<cr>", { desc = "编辑任务正文" })
		vim.keymap.set("n", "<leader>mtt", "<cmd>TodoTag<cr>", { desc = "给任务加/删/设置标签" })
		vim.keymap.set("n", "<leader>mtD", "<cmd>TodoDue<cr>", { desc = "设置/清除到期日（@YYYY-MM-DD）" })
		vim.keymap.set(
			"n",
			"<leader>mtf",
			"<cmd>TodoFilter<cr>",
			{ desc = "按标签/状态/路径/到期日筛选 TODO（! 清除）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mtw",
			"<cmd>TodoFilter due:week<cr>",
			{ desc = "只看本周到期（due:week）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mto",
			"<cmd>TodoFilter due:overdue<cr>",
			{ desc = "只看已过期（due:overdue）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mtc",
			"<cmd>TodoContext<cr>",
			{ desc = "复制任务上下文（Markdown，供 AI）" }
		)
		vim.keymap.set("n", "<leader>mtl", "<cmd>TodoLink<cr>", { desc = "代码关联任务" })

		-- 归档（ma-）
		vim.keymap.set(
			"n",
			"<leader>maa",
			"<cmd>TodoArchive<cr>",
			{ desc = "归档任务组（:TodoArchive! 强制）" }
		)
		vim.keymap.set("n", "<leader>mau", "<cmd>TodoUnarchive<cr>", { desc = "恢复归档任务" })
		vim.keymap.set("n", "<leader>mav", "<cmd>TodoArchiveView<cr>", { desc = "归档任务树 (QF)" })
		vim.keymap.set("n", "<leader>maq", "<cmd>TodoArchiveQF<cr>", { desc = "归档任务平铺 (QF)" })

		-- 视图 / 打开方式（mv-）
		vim.keymap.set("n", "<leader>mvf", "<cmd>TodoFloat<cr>", { desc = "浮窗打开" })
		vim.keymap.set("n", "<leader>mvs", "<cmd>TodoSplit<cr>", { desc = "水平分割打开" })
		vim.keymap.set("n", "<leader>mvv", "<cmd>TodoVSplit<cr>", { desc = "垂直分割打开" })
		vim.keymap.set("n", "<leader>mve", "<cmd>TodoEdit<cr>", { desc = "编辑模式打开" })
		vim.keymap.set("n", "<leader>mvc", "<cmd>TodoCalendar<cr>", { desc = "项目月历（时间维度查看任务）" })
		vim.keymap.set("n", "<leader>mp", "<cmd>SmartPreview<cr>", { desc = "todo2: todo预览" })

		-- 链接（ml-）
		vim.keymap.set("n", "<leader>mla", "<cmd>TodoLinks<cr>", { desc = "显示所有双链标记 (QF)" })
		vim.keymap.set(
			"n",
			"<leader>mlb",
			"<cmd>TodoLinksBuf<cr>",
			{ desc = "显示当前缓冲区双链标记 (LocList)" }
		)

		-- Git 集成（mg-）
		vim.keymap.set("n", "<leader>mgs", "<cmd>TodoGitSync<cr>", { desc = "增量同步提交并应用任务引用" })
		vim.keymap.set(
			"n",
			"<leader>mgr",
			"<cmd>TodoGitReview<cr>",
			{ desc = "提交前自查：脏文件中的任务锚点" }
		)
		vim.keymap.set("n", "<leader>mgb", "<cmd>TodoGitBlame<cr>", { desc = "查看任务锚点的 git 历史" })
	end,
}
