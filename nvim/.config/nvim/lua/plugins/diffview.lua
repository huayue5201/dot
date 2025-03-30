-- https://chatgpt.com/c/67e8addd-855c-800d-aec5-193b775bb237

return {
	"sindrets/diffview.nvim",
	keys = {
		{ "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
		{ "<leader>gdc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
		{ "<leader>gdf", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview File History" },
	},
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("diffview").setup({
			diff_binaries = true, -- 是否显示二进制文件的差异
			enhanced_diff_hl = true, -- 是否启用增强的差异高亮
			git_cmd = { "git" }, -- 指定 git 执行文件及默认参数
			hg_cmd = { "hg" }, -- 指定 mercurial 执行文件及默认参数
			use_icons = true, -- 是否启用图标，依赖于 nvim-web-devicons 插件
			show_help_hints = true, -- 是否显示帮助提示
			watch_index = true, -- 当 git 索引发生变化时更新视图和索引缓冲区
			icons = { -- 仅当 use_icons 为 true 时生效
				folder_closed = "", -- 文件夹关闭时的图标
				folder_open = "", -- 文件夹打开时的图标
			},
			signs = {
				fold_closed = "", -- 折叠文件的图标
				fold_open = "", -- 展开文件的图标
				done = "✓", -- 操作完成时的标记图标
			},
			view = {
				-- 配置不同类型视图的布局和行为
				-- 可用的布局类型：
				--  'diff1_plain'    单一文件差异视图
				--  'diff2_horizontal'  水平对比视图
				--  'diff2_vertical'    垂直对比视图
				--  'diff3_horizontal'  三方对比水平视图
				--  'diff3_vertical'    三方对比垂直视图
				--  'diff3_mixed'       三方对比混合视图
				--  'diff4_mixed'       四方对比混合视图
				-- 具体参考 |diffview-config-view.x.layout|
				default = {
					layout = "diff2_horizontal", -- 配置改动文件和暂存文件的差异视图布局为水平对比
					disable_diagnostics = true, -- 在视图中临时禁用差异缓冲区的诊断信息
					winbar_info = true, -- 显示窗口栏信息，参考 |diffview-config-view.x.winbar_info|
				},
				merge_tool = {
					-- 配置在合并或变基时冲突文件的差异视图布局
					layout = "diff3_horizontal", -- 三方合并冲突的水平对比视图
					disable_diagnostics = true, -- 在视图中临时禁用诊断信息
					winbar_info = true, -- 显示窗口栏信息，参考 |diffview-config-view.x.winbar_info|
				},
				file_history = {
					-- 配置文件历史视图的差异布局
					layout = "diff2_horizontal", -- 配置为水平对比视图
					disable_diagnostics = true, -- 在视图中临时禁用诊断信息
					winbar_info = true, -- 显示窗口栏信息，参考 |diffview-config-view.x.winbar_info|
				},
			},
			file_panel = {
				listing_style = "tree", -- 文件面板显示样式，可选 'list' 或 'tree'
				tree_options = { -- 当 listing_style 为 'tree' 时有效
					flatten_dirs = true, -- 是否展开只包含一个子目录的文件夹
					folder_statuses = "only_folded", -- 文件夹状态显示方式，'never', 'only_folded', 或 'always'
				},
				win_config = { -- 配置文件面板窗口
					position = "bottom", -- 文件面板显示在底部
					width = 35, -- 文件面板宽度
					win_opts = {}, -- 窗口的其他配置选项
				},
			},
			file_history_panel = {
				log_options = { -- 配置日志选项
					git = {
						single_file = {
							diff_merges = "combined", -- 合并单个文件的差异视图为 "combined"
						},
						multi_file = {
							diff_merges = "first-parent", -- 合并多个文件的差异视图为 "first-parent"
						},
					},
					hg = {
						single_file = {},
						multi_file = {},
					},
				},
				win_config = { -- 配置文件历史面板窗口
					position = "bottom", -- 文件历史面板显示在底部
					height = 16, -- 文件历史面板高度
					win_opts = {}, -- 窗口的其他配置选项
				},
			},
			commit_log_panel = {
				win_config = {}, -- 配置提交日志面板窗口
			},
			default_args = { -- 默认的命令参数
				DiffviewOpen = {}, -- 打开差异视图时的默认参数
				DiffviewFileHistory = {}, -- 打开文件历史视图时的默认参数
			},
			hooks = {
				diff_buf_read = function(bufnr)
					-- Change local options in diff buffers
					vim.opt_local.wrap = false
					vim.opt_local.list = false
					vim.opt_local.colorcolumn = { 80 }
				end,
				view_opened = function(view)
					print(("A new %s was opened on tab page %d!"):format(view.class:name(), view.tabpage))
				end,
			},
		})
	end,
}
