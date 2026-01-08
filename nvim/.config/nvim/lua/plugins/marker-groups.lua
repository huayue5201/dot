-- https://github.com/jameswolensky/marker-groups.nvim

return {
	"jameswolensky/marker-groups.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required
		"ibhagwan/fzf-lua", -- Optional: fzf-lua picker
		-- mini.pick is part of mini.nvim; this plugin vendors mini.nvim for tests,
		-- but you can also install mini.nvim explicitly to use mini.pick system-wide
		-- "nvim-mini/mini.nvim",
	},
	config = function()
		require("marker-groups").setup({
			---------------------------------------------------------------------------
			-- 数据持久化配置
			---------------------------------------------------------------------------
			-- data_dir: 用于存储标记组（marker groups）的数据目录
			-- 默认放在 Neovim 的 stdpath("data") 下，确保跨会话持久化
			data_dir = vim.fn.stdpath("data") .. "/marker-groups",

			---------------------------------------------------------------------------
			-- 日志系统
			---------------------------------------------------------------------------
			debug = false, -- 是否启用 debug 模式（会输出更多日志）
			log_level = "info", -- 日志等级："debug" | "info" | "warn" | "error"

			---------------------------------------------------------------------------
			-- 右侧抽屉式 viewer（用于查看所有标记）
			---------------------------------------------------------------------------
			drawer_config = {
				width = 60, -- 抽屉宽度（30~120 之间）
				side = "right", -- 抽屉位置："left" 或 "right"
				border = "rounded", -- 边框样式
				title_pos = "center", -- 标题位置："left" | "center" | "right"
			},

			---------------------------------------------------------------------------
			-- 在 viewer/preview 中显示标记时，展示多少行上下文
			---------------------------------------------------------------------------
			context_lines = 2, -- 上下文行数（例如显示标记所在行的前后 2 行）

			---------------------------------------------------------------------------
			-- 虚拟文本（virtual text）显示 & 高亮组
			---------------------------------------------------------------------------
			max_annotation_display = 50, -- 注释过长时截断显示的最大字符数
			highlight_groups = {
				marker = "MarkerGroupsMarker", -- 标记本身的高亮
				annotation = "MarkerGroupsAnnotation", -- 注释文本的高亮
				context = "MarkerGroupsContext", -- 上下文行的高亮
				multiline_start = "MarkerGroupsMultilineStart", -- 多行注释开始高亮
				multiline_end = "MarkerGroupsMultilineEnd", -- 多行注释结束高亮
			},

			---------------------------------------------------------------------------
			-- 快捷键绑定（声明式，可覆盖或禁用）
			---------------------------------------------------------------------------
			keymaps = {
				enabled = true, -- 是否启用所有快捷键
				prefix = "<leader>v", -- 所有 marker-groups 快捷键的前缀

				mappings = {
					-----------------------------------------------------------------------
					-- 单个标记（marker）相关操作
					-----------------------------------------------------------------------
					marker = {
						add = {
							suffix = "a",
							mode = { "n", "v" }, -- 支持 normal 和 visual 模式
							desc = "添加标记",
						},
						edit = {
							suffix = "e",
							desc = "编辑光标处的标记",
						},
						delete = {
							suffix = "d",
							desc = "删除光标处的标记",
						},
						list = {
							suffix = "l",
							desc = "列出当前 buffer 的所有标记",
						},
						info = {
							suffix = "i",
							desc = "显示光标处标记的详细信息",
						},
					},

					-----------------------------------------------------------------------
					-- 标记组（group）相关操作
					-----------------------------------------------------------------------
					group = {
						create = {
							suffix = "gc",
							desc = "创建标记组",
						},
						select = {
							suffix = "gs",
							desc = "选择标记组",
						},
						list = {
							suffix = "gl",
							desc = "列出所有标记组",
						},
						rename = {
							suffix = "gr",
							desc = "重命名标记组",
						},
						delete = {
							suffix = "gd",
							desc = "删除标记组",
						},
						info = {
							suffix = "gi",
							desc = "显示当前激活的标记组信息",
						},
						from_branch = {
							suffix = "gb",
							desc = "基于当前 Git 分支创建标记组",
						},
					},

					-----------------------------------------------------------------------
					-- Viewer（抽屉）相关操作
					-----------------------------------------------------------------------
					view = {
						toggle = {
							suffix = "v",
							desc = "打开/关闭标记抽屉 viewer",
						},
					},
				},
			},

			---------------------------------------------------------------------------
			-- Picker 后端（用于选择标记、标记组）
			---------------------------------------------------------------------------
			-- 可选值：
			--   'vim'（默认）| 'snacks' | 'fzf-lua' | 'mini.pick' | 'telescope'
			-- 如果填了无效值，会自动回退到 'vim'
			picker = "fzf-lua",
		})
	end,
}
