-- https://github.com/huayue5201/todo2

return {
	dir = "~/neovim-plugins/todo2",
	"huayue5201/todo2",
	dev = true,
	dependencies = { "nvim-store3" },
	name = "todo2",
	-- 懒加载已由插件端处理（plugin/todo2.lua 惰性触发 setup），无需 lazy 配置
	init = function()
		-- 可选：自定义配置（以下均为顶层键，均有默认值，按需覆盖）
		vim.g.todo2_config = {
			-- 核心开关
			show_status = true, -- 显示状态
			conceal_enable = true, -- TODO 文件 conceal 渲染（复选框图标等）

			-- 状态高亮颜色（对应 TodoStatusXxx 高亮组）
			status_colors = {
				normal = "#51cf66",
				urgent = "#ff6b6b",
				waiting = "#ffd43b",
				completed = "#868e96",
				archived = "#868e96",
			},

			-- 解析器行为
			parser = {
				indent_width = 2, -- 缩进宽度（空格数）
				empty_line_reset = 1, -- 空行重置
				context_split = false, -- 上下文拆分
			},

			-- 进度条样式
			progress_bar = {
				style = "full",
				chars = {
					filled = "▰",
					empty = "▱",
					separator = " ",
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
				width = 58, -- position = "right" 时的宽度
				height = 12, -- position = "bottom" 时的高度
				focus_on_jump = false, -- true 时 <CR> 跳转后焦点跟随到代码窗口
			},

			-- 状态图标（图标 + 颜色 + 标签）
			status_icons = {
				normal = { icon = "", color = "#51cf66", label = "正常" },
				urgent = { icon = "󰚰", color = "#ff6b6b", label = "紧急" },
				waiting = { icon = "󱫖", color = "#ffd43b", label = "等待" },
				completed = { icon = "", color = "#868e96", label = "完成" },
				archived = { icon = "📦", color = "#868e96", label = "归档" },
			},

			-- 归档区域标题前缀
			archive_section = {
				title_prefix = "## Archived",
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
		------------------------------------------------------------------
		-- 文件操作
		vim.keymap.set("n", "<leader>mn", "<cmd>TodoNew<cr>", { desc = "创建 TODO 文件" })
		vim.keymap.set("n", "<leader>mr", "<cmd>TodoRename<cr>", { desc = "重命名 TODO 文件" })
		vim.keymap.set("n", "<leader>mc", "<cmd>TodoDelete<cr>", { desc = "删除 TODO 文件" })

		-- 归档 / 恢复
		vim.keymap.set("n", "<leader>mg", "<cmd>TodoArchive<cr>", { desc = "归档任务组" })
		vim.keymap.set("n", "<leader>mu", "<cmd>TodoRestore<cr>", { desc = "恢复归档任务" })

		-- 状态
		vim.keymap.set("n", "<leader>mt", "<cmd>TodoStatus<cr>", { desc = "选择任务状态" })

		-- 从代码创建任务
		vim.keymap.set("n", "<leader>ma", "<cmd>TodoAdd<cr>", { desc = "从代码创建任务" })

		-- 链接
		vim.keymap.set("n", "<leader>mq", "<cmd>TodoLinks<cr>", { desc = "显示所有双链标记 (QF)" })
		vim.keymap.set(
			"n",
			"<leader>ml",
			"<cmd>TodoLinksBuf<cr>",
			{ desc = "显示当前缓冲区双链标记 (LocList)" }
		)
		vim.keymap.set("n", "<leader>md", "<cmd>TodoDrawer<cr>", { desc = "打开任务抽屉" })

		-- 打开 TODO 文件
		vim.keymap.set("n", "<leader>mf", "<cmd>TodoFloat<cr>", { desc = "浮窗打开" })
		vim.keymap.set("n", "<leader>ms", "<cmd>TodoSplit<cr>", { desc = "水平分割打开" })
		vim.keymap.set("n", "<leader>mv", "<cmd>TodoVSplit<cr>", { desc = "垂直分割打开" })
		vim.keymap.set("n", "<leader>me", "<cmd>TodoEdit<cr>", { desc = "编辑模式打开" })

		-- 额外
		vim.keymap.set("n", "<C-k>", "<cmd>SmartPreview<cr>", { desc = "todo2: todo预览" })
	end,
}
