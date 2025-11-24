-- https://github.com/A7Lavinraj/fyler.nvim

return {
	"A7Lavinraj/fyler.nvim",
	branch = "stable", -- 推荐使用稳定分支
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		hooks = {
			on_delete = nil,
			on_rename = nil,
			on_highlight = nil,
		},
		integrations = {
			icon = "nvim_web_devicons",
		},
		views = {
			finder = {
				close_on_select = true, -- 选中文件后关闭 Fyler 界面
				confirm_simple = false, -- 简单操作是否自动确认
				default_explorer = false, -- 是否替换 netrw 为 Fyler
				delete_to_trash = false, -- 删除是否移到回收站
				git_status = {
					enabled = true, -- 是否显示 git 状态
					symbols = {
						Untracked = "?",
						Added = "+",
						Modified = "*",
						Deleted = "x",
						Renamed = ">",
						Copied = "~",
						Conflict = "!",
						Ignored = "#",
					},
				},
				icon = {
					directory_collapsed = nil,
					directory_empty = nil,
					directory_expanded = nil,
				},
				indentscope = {
					enabled = true, -- 显示缩进线 (tree 结构)
					group = "FylerIndentMarker",
					marker = "│",
				},
				mappings = {
					["q"] = "CloseView",
					["<CR>"] = "Select",
					["<C-t>"] = "SelectTab",
					["|"] = "SelectVSplit",
					["-"] = "SelectSplit",
					["^"] = "GotoParent",
					["="] = "GotoCwd",
					["."] = "GotoNode",
					["#"] = "CollapseAll",
					["<BS>"] = "CollapseNode",
				},
				follow_current_file = true, -- 跟踪当前打开文件所在目录
				watcher = {
					enabled = false, -- 是否开启文件系统监视 (刷新)
				},
				win = {
					border = vim.o.winborder == "" and "single" or vim.o.winborder,
					buf_opts = {
						filetype = "fyler",
						syntax = "fyler",
						buflisted = false,
						buftype = "acwrite",
						expandtab = true,
						shiftwidth = 2,
					},
					kind = "split_left_most", -- 默认窗口类型（也可选 float / split / …）
					kinds = {
						float = {
							height = "70%",
							width = "70%",
							top = "10%",
							left = "15%",
						},
						replace = {},
						split_above = {
							height = "70%",
						},
						split_above_all = {
							height = "70%",
							win_opts = {
								winfixheight = true,
							},
						},
						split_below = {
							height = "70%",
						},
						split_below_all = {
							height = "70%",
							win_opts = {
								winfixheight = true,
							},
						},
						split_left = {
							width = "70%",
						},
						split_left_most = {
							width = "30%",
							win_opts = {
								winfixwidth = true,
							},
						},
						split_right = {
							width = "30%",
						},
						split_right_most = {
							width = "30%",
							win_opts = {
								winfixwidth = true,
							},
						},
					},
					win_opts = {
						concealcursor = "nvic",
						conceallevel = 3,
						cursorline = false,
						number = false,
						relativenumber = false,
						winhighlight = "Normal:FylerNormal,NormalNC:FylerNormalNC",
						wrap = false,
					},
				},
			},
		},
	},
	config = function(_, opts)
		require("fyler").setup(opts)

		-- 自定义一个切换命令或键位
		vim.keymap.set("n", "<leader>ee", function()
			require("fyler").toggle({ kind = "split_left_most" })
		end, { desc = "Toggle Fyler 文件树" })
	end,
}
