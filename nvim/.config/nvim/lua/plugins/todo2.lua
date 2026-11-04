-- https://github.com/huayue5201/todo2

return {
	dir = "~/neovim-plugins/todo2",
	dependencies = { { dir = "~/neovim-plugins/nvim-store3" } },
	name = "todo2",
	-- setup 由插件端 plugin/todo2.lua 惰性触发；加载器没有 lazy 字段，无需配置
	init = function()
		-- 可选：自定义配置（以下均为顶层键，均有默认值，按需覆盖）
		-- 唯一完整参考：:h todo2（:Todo help 打开）
		vim.g.todo2_config = {
			-- 核心开关
			conceal_enable = true, -- TODO 文件 conceal 渲染（状态 checkbox → 图标；@created 默认隐藏）

			-- 解析器行为
			parser = {
				indent_width = 2, -- 缩进宽度（空格数）
				empty_line_reset = 1, -- 空行重置
				context_split = false, -- 上下文拆分
			},

			-- 启动时对项目内全部 TODO 文件做一次全量对账（自愈漏事件造成的漂移）
			sync = {
				reconcile_on_start = true,
			},

			-- 任务正文（任务行下方的缩进续行）
			description = {
				fold = true, -- TODO 文件里默认折叠正文
				format_on_save = true, -- 保存时把正文缩进规整到列表项内容列
			},

			-- 代码文件里的任务渲染（默认：任务标签画在代码行上方的虚拟行）
			code_render = {
				position = "above", -- "above" | "below" | "inline"
				max_lines = 3, -- 同一代码行最多展示几个任务，超出折叠为「代表任务 + +N」
				virt_lines_overflow = "trunc", -- "trunc" | "scroll" | "auto" | "wrap"
			},

			-- 到期日输入：true = 三格日期面板，false = 一行表达式输入（:h todo2-date-panel）
			due = {
				panel = true,
			},

			-- 智能预览（:TodoView preview）同一锚点最多平铺几个窗口
			preview = {
				max_blocks = 20,
			},

			-- 进度条样式（字形在 icons.progress，这里只管长度和高亮组）
			progress_bar = {
				style = "full",
				length = { min = 5, max = 20 },
				highlights = {
					done = "Todo2ProgressDone",
					todo = "Todo2ProgressTodo",
				},
			},

			-- 视图（viewer）显示配置
			viewer_show_icons = true,
			viewer_show_child_count = true,
			viewer_file_header_style = "─ %s ──[ %d tasks ]",

			-- 所有字形都在这里：任意项设 "" 即不显示（状态图标见下方 status）
			-- 详见 :h todo2-icons；没有 Nerd Font 也可全换成 ASCII
			icons = {
				time = "󰑥 ", -- 行尾「最近改动时间」前缀（终态不加）
				separator = "·", -- 时间与到期日之间的分隔
				body = " ", -- 正文折叠后的占位
				warning = "⚠", -- 正文末尾疑似元数据时的提醒
				unknown_status = "●", -- 状态没有配 icon 时的兜底
				-- 树形缩进（抽屉 / 视图 / 代码侧分组共用）
				tree = {
					top = "│ ",
					middle = "├─",
					last = "└─",
					ws = "  ",
				},
				-- 子任务进度条
				progress = {
					filled = "▰",
					empty = "▱",
				},
				-- 代码文件里的任务标记
				code = {
					above = "󱞡 ", -- 组内上方分组箭头
					below = "󱞽 ", -- 组内下方分组箭头
					branch = "└ ", -- 缩进分支
					bar = " │ ", -- 组内竖线
				},
				-- 抽屉
				drawer = {
					fold_open = "▾",
					fold_closed = "▸",
					cut = "󰆐 ",
					code_link = "󰦼 ", -- 任务自己的代码锚点
					code_link_inherited = "󰮵", -- 仅继承自父任务的锚点
				},
				file = "📁", -- 文件分组标题（归档组用 archived 状态的图标）
				-- 月历徽章
				calendar = {
					commitment = "●", -- 承诺层（有 @due / @start）
					mark = "○", -- 活动层（无日期，按最后修改时间）
				},
			},

			-- 任务树抽屉（:TodoDrawer / :Todo）
			drawer = {
				position = "right", -- "right" | "bottom"（bottom 上下拆分可展示更多）
				width = 60, -- position = "right" 时的宽度
				height = 12, -- position = "bottom" 时的高度
				focus_on_jump = false, -- true 时 <CR> 跳转后焦点跟到代码窗口
				expand_lines = true, -- 光标行超出宽度时用浮窗补全完整内容
			},

			-- 项目月历（:TodoCalendar）：只收录带 @due / @start 的活动任务
			calendar = {
				first_day_of_week = "monday", -- "monday" | "sunday"
				winblend = 0, -- 浮层透明度（0 = 不透明）
				show_completed = true, -- false 时已完成任务不计数、不上格
			},

			-- 状态：状态全部编码进 checkbox，文件是唯一真相源
			-- `- [ ]` 第一个活跃状态、`- [d]` doing、`- [b]` blocked、`- [x]` 完成、`- [>]` 归档
			-- checkbox 省略时：第一个状态用空格，其余取 label 里第一个没被占用的字母
			-- （空格 / x / X / > 永远留给终态）；type = incomplete（默认）/ complete / inactive
			status = {
				cycle = {
					{ label = "todo", icon = " ", color = "#51cf66" },
					{ label = "doing", icon = "▶ ", color = "#f5c2e7", checkbox = "d" },
					{ label = "blocked", icon = "⛔ ", color = "#ff6b6b", checkbox = "b" },
				},
				-- 终态只允许改显示，语义（完成 / 归档）不变
				terminal = {
					completed = { icon = "✔", color = "#868e96" },
					archived = { icon = "📦", color = "#868e96" },
				},
			},

			-- 命名筛选（:TodoFilter save NAME 写入本表，:TodoFilter @NAME 应用）
			filters = {},

			-- 归档区域标题前缀（归档任务存在文件内 `## Archived (YYYY-MM)` 段）
			archive_section = {
				title_prefix = "## Archived",
			},

			-- 归档（:TodoArchive / :TodoUnarchive；归档只是移入归档段，可逆）
			archive = {
				allow_unfinished = true, -- 是否允许归档含未完成任务的组（<leader>mA! 可强制）
				include_in_render = false, -- 抽屉初次打开是否并入归档任务（抽屉内 A 可切换）
				auto_after_days = 0, -- 整棵子树完成后自动归档的天数（0 = 关闭）
			},

			-- 孤儿任务回收（任务行被手删后，store 记录先隔离再清理）
			orphan = {
				enabled = true,
				retention_days = 30, -- 隔离超过该天数仍无文件恢复即清除（0 = 永不清除）
			},

			-- 项目级回收（项目从磁盘删掉 / 改名后遗留的 TODO 目录）
			-- 只在项目根确实不存在（ENOENT）且超过该天数时才移动，绝不删除
			projects = {
				retention_days = 30, -- 0 = 永不自动移动，平时只报告；:TodoGc! 才动手
			},

			-- 性能观测：关闭时插桩零开销，开启后用 :TodoProfile 看 count/avg/max
			profile = {
				enabled = false,
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

			-- MCP 接入点：publish = true 时 setup 阶段就把本实例的 RPC 地址给 MCP 桥
			mcp = {
				publish = true,
			},

			-- 任务上下文（供 AI / MCP；:TodoContext 随时可用，不受 mcp.publish 影响）
			ai = {
				include_code = true, -- 是否附带代码块正文
				include_ancestors = true, -- 是否附带祖先链
				include_children = 1, -- 子树层数：true = 全部，数字 = 层数
				max_code_lines = 200, -- 代码正文最多取多少行（0 = 不限）
			},

			-- Git 集成（提交消息关单 / 锚点历史 / 提交前自查）
			git = {
				enable = true, -- 总开关（:TodoGit sync! 可临时绕过）
				trigger = "manual", -- "manual" | "on_open"（on_open 时打开 TODO 自动增量同步）
				show_metadata = true, -- 在查看器 / 抽屉显示关联提交
				refs = {
					-- 提交消息里出现 todo:<id> 时把该任务标为完成
					{ pattern = "[Tt]odo[:：]%s*([0-9a-z]+)", status = "completed" },
				},
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
		-- 只取分组前缀以外的单字母：mf/mt/ma/mv/ml/mg 是分组，mp 已被 TodoView preview 用掉，
		-- 所以这里只用 mn / mc / md / mh，不抢分组前缀（否则 maa、mvv 这类进不去）。
		-- 同一命令只在单键别名处保留一份，分组里不再重复定义。
		------------------------------------------------------------------
		-- 键位约定（一套可推导的规则，不是零散记忆）：
		--   全局 = <leader>m<组><动作>，抽屉单键 == 这个动作字母（大小写一致）。
		--   组字母 = 语义域：t 任务 / f 文件 / v 视图 / a 归档 / l 链接 / g git。
		--   例：抽屉里 D 设到期日  ↔  <leader>mtD；抽屉里 o 预览  ↔  <leader>mvo。
		vim.keymap.set("n", "<leader>md", "<cmd>Todo<cr>", { desc = "TODO: 入口（任务抽屉）" })
		vim.keymap.set("n", "<leader>mh", "<cmd>Todo help<cr>", { desc = "TODO: 完整帮助 :h todo2" })
		vim.keymap.set("n", "<leader>mc", "<cmd>TodoAdd<cr>", { desc = "TODO: 从当前代码行建任务" })

		-- ── 任务组 mt-（末位 == 抽屉键）────────────────────────────
		vim.keymap.set("n", "<leader>mts", "<cmd>TodoStatus<cr>", { desc = "选择任务状态（抽屉 s）" })
		vim.keymap.set("n", "<leader>mtt", "<cmd>TodoTag<cr>", { desc = "编辑标签（抽屉 t）" })
		vim.keymap.set("n", "<leader>mtD", "<cmd>TodoDue<cr>", { desc = "设/清到期日（抽屉 D）" })
		vim.keymap.set("n", "<leader>mtS", "<cmd>TodoStart<cr>", { desc = "设/清开始日（抽屉 S）" })
		vim.keymap.set(
			"n",
			"<leader>mtC",
			"<cmd>TodoCalendar<cr>",
			{ desc = "打开项目月历（抽屉 C 里点选日期）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mti",
			"<cmd>TodoSet<cr>",
			{ desc = "属性面板 状态/标签/开始/到期（抽屉 i）" }
		)
		vim.keymap.set("n", "<leader>mte", "<cmd>TodoTask rename<cr>", { desc = "改任务标题（抽屉 e）" })
		vim.keymap.set("n", "<leader>mtE", "<cmd>TodoTask desc<cr>", { desc = "编辑任务正文（抽屉 E）" })
		vim.keymap.set(
			"n",
			"<leader>mtc",
			"<cmd>TodoContext<cr>",
			{ desc = "复制任务上下文 Markdown（抽屉 c）" }
		)
		vim.keymap.set("n", "<leader>mtl", "<cmd>TodoLink<cr>", { desc = "把代码位置关联到任务" })
		vim.keymap.set("n", "<leader>mtf", "<cmd>TodoFilter<cr>", { desc = "筛选（抽屉 f）" })
		vim.keymap.set("n", "<leader>mtF", "<cmd>TodoFilter!<cr>", { desc = "清除筛选（抽屉 F）" })
		vim.keymap.set("n", "<leader>mtO", "<cmd>TodoSort<cr>", { desc = "同级按状态排序（抽屉 O）" })
		vim.keymap.set("n", "<leader>mtw", "<cmd>TodoFilter due:week<cr>", { desc = "预设筛选：本周到期" })
		vim.keymap.set("n", "<leader>mto", "<cmd>TodoFilter due:overdue<cr>", { desc = "预设筛选：已过期" })

		-- ── 视图组 mv-（末位 == 抽屉键）────────────────────────────
		vim.keymap.set(
			"n",
			"<leader>mvo",
			"<cmd>TodoView float<cr>",
			{ desc = "浮窗预览 TODO 文件（抽屉 o）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mvP",
			"<cmd>TodoView preview<cr>",
			{ desc = "智能预览 TODO/代码（抽屉 P 预览关联代码）" }
		)
		vim.keymap.set("n", "<leader>mvs", "<cmd>TodoView split<cr>", { desc = "水平分割打开" })
		vim.keymap.set("n", "<leader>mvv", "<cmd>TodoView vsplit<cr>", { desc = "垂直分割打开" })
		vim.keymap.set("n", "<leader>mve", "<cmd>TodoView edit<cr>", { desc = "编辑模式打开" })
		vim.keymap.set("n", "<leader>mvc", "<cmd>TodoCalendar<cr>", { desc = "项目月历（时间维度视图）" })

		-- ── 文件组 mf-（末位 == 抽屉键；文件头上的 a/r/d）──────────
		vim.keymap.set("n", "<leader>mfa", "<cmd>TodoFile new<cr>", { desc = "新建 TODO 文件（抽屉 a）" })
		vim.keymap.set("n", "<leader>mfr", "<cmd>TodoFile rename<cr>", { desc = "重命名文件（抽屉 r）" })
		vim.keymap.set(
			"n",
			"<leader>mfd",
			"<cmd>TodoFile delete<cr>",
			{ desc = "删除文件（抽屉在文件头按 d）" }
		)

		-- ── 归档组 ma- ────────────────────────────────────────────
		vim.keymap.set("n", "<leader>max", "<cmd>TodoArchive<cr>", { desc = "归档任务组（抽屉 x）" })
		vim.keymap.set("n", "<leader>mau", "<cmd>TodoUnarchive<cr>", { desc = "恢复归档任务" })
		vim.keymap.set("n", "<leader>mav", "<cmd>TodoArchiveView<cr>", { desc = "归档任务树 (QF)" })
		vim.keymap.set("n", "<leader>maq", "<cmd>TodoArchiveView!<cr>", { desc = "归档任务平铺 (QF)" })

		-- ── 链接组 ml- ────────────────────────────────────────────
		vim.keymap.set("n", "<leader>mla", "<cmd>TodoLinks<cr>", { desc = "全部双链标记 (QF)" })
		vim.keymap.set("n", "<leader>mlb", "<cmd>TodoLinks!<cr>", { desc = "当前缓冲区双链标记 (LocList)" })

		-- ── git 组 mg-（抽屉内 gs/gr/gb 同字母）───────────────────
		vim.keymap.set(
			"n",
			"<leader>mgs",
			"<cmd>TodoGit sync<cr>",
			{ desc = "增量同步提交里的任务引用（抽屉 gs）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mgr",
			"<cmd>TodoGit review<cr>",
			{ desc = "提交前自查脏文件里的锚点（抽屉 gr）" }
		)
		vim.keymap.set(
			"n",
			"<leader>mgb",
			"<cmd>TodoGit blame<cr>",
			{ desc = "查任务锚点的提交历史（抽屉 gb）" }
		)
	end,
}
