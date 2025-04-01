-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	cmd = "Neogit",
	keys = {
		{ "<leader>go", desc = "Neogit" },
		{ "<leader>gc", desc = "Neogit commit" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim", -- required
		-- https://github.com/sindrets/diffview.nvim
		"sindrets/diffview.nvim", -- optional - Diff integration
	},
	config = function()
		local neogit = require("neogit")

		neogit.setup({
			-- 隐藏状态栏顶部的提示信息
			disable_hint = false,
			-- 禁用根据光标位置改变缓冲区的高亮
			disable_context_highlighting = false,
			-- 禁用部分/项目/块的标志
			disable_signs = false,
			-- 分支分歧时，提示强制推送
			prompt_force_push = true,
			-- 提交编辑器启动模式：`true` 保持 Neovim 为普通模式，`false` 切换为插入模式，`"auto"` 则会在提交信息为空时进入插入模式
			disable_insert_on_commit = "auto",
			-- 启用文件监视器，以便在 `.git/` 目录发生变化时刷新状态缓冲区
			filewatcher = {
				interval = 1000,
				enabled = true,
			},
			-- 图形样式：
			-- "ascii" 使用 Git CLI 生成的图形，"unicode" 使用类似 https://github.com/rbong/vim-flog 的图形
			-- "kitty" 使用类似 https://github.com/isakbm/gitgraph.nvim 的图形
			graph_style = "kitty",
			-- 默认显示相对日期
			commit_date_format = nil,
			log_date_format = nil,
			-- 配置 Git 服务的 URL，用于在分支弹出操作中创建 "pull request"
			git_services = {
				["github.com"] = "https://github.com/${owner}/${repository}/compare/${branch_name}?expand=1",
				["bitbucket.org"] = "https://bitbucket.org/${owner}/${repository}/pull-requests/new?source=${branch_name}&t=1",
				["gitlab.com"] = "https://gitlab.com/${owner}/${repository}/merge_requests/new?merge_request[source_branch]=${branch_name}",
				["azure.com"] = "https://dev.azure.com/${owner}/_git/${repository}/pullrequestcreate?sourceRef=${branch_name}&targetRef=${target}",
			},
			-- 配置 telescope 排序器，默认使用 'fuzzy_with_index_bias'，下面的例子使用 fzf 排序器
			telescope_sorter = function()
				return require("telescope").extensions.fzf.native_fzf_sorter()
			end,
			-- 保持会话之间设置的值
			remember_settings = true,
			-- 允许每个项目独立保存设置
			use_per_project_settings = true,
			-- 忽略某些设置
			ignored_settings = {
				"NeogitPushPopup--force-with-lease",
				"NeogitPushPopup--force",
				"NeogitPullPopup--rebase",
				"NeogitCommitPopup--allow-empty",
				"NeogitRevertPopup--no-edit",
			},
			-- 配置高亮组功能
			highlight = {
				italic = true,
				bold = true,
				underline = true,
			},
			-- 设置为 false 时，你需要自己定义所有快捷键
			use_default_keymaps = true,
			-- 自动刷新 Neogit 内部状态
			auto_refresh = true,
			-- 用于 git branch 命令的 `--sort` 选项，默认按提交日期降序排序
			sort_branches = "-committerdate",
			-- 默认分支名称
			initial_branch_name = "",
			-- 改变 Neogit 打开的方式
			kind = "tab",
			-- 禁用行号
			disable_line_numbers = true,
			-- 禁用相对行号
			disable_relative_line_numbers = true,
			-- 显示控制台超时的时间（单位毫秒）
			console_timeout = 2000,
			-- 超过超时时间时自动显示控制台
			auto_show_console = true,
			-- 进程退出时，如果状态为 0 (成功)，则自动关闭控制台
			auto_close_console = true,
			notification_icon = "󰊢",
			-- 状态配置
			status = {
				show_head_commit_hash = true,
				recent_commit_count = 10,
				HEAD_padding = 10,
				HEAD_folded = false,
				mode_padding = 3,
				mode_text = {
					M = "modified",
					N = "new file",
					A = "added",
					D = "deleted",
					C = "copied",
					U = "updated",
					R = "renamed",
					DD = "unmerged",
					AU = "unmerged",
					UD = "unmerged",
					UA = "unmerged",
					DU = "unmerged",
					AA = "unmerged",
					UU = "unmerged",
					["?"] = "",
				},
			},
			-- 提交编辑器配置
			commit_editor = {
				kind = "tab",
				show_staged_diff = true,
				staged_diff_split_kind = "split", -- "split" 显示在提交编辑器下方
				spell_check = true,
			},
			-- 提交选择视图配置
			commit_select_view = {
				kind = "tab",
			},
			-- 提交视图配置
			commit_view = {
				kind = "vsplit",
				verify_commit = vim.fn.executable("gpg") == 1, -- 如果 GPG 可用，则启用验证
			},
			-- 日志视图配置
			log_view = {
				kind = "tab",
			},
			-- 变基编辑器配置
			rebase_editor = {
				kind = "auto",
			},
			-- 回溯日志视图配置
			reflog_view = {
				kind = "tab",
			},
			-- 合并编辑器配置
			merge_editor = {
				kind = "auto",
			},
			-- 描述编辑器配置
			description_editor = {
				kind = "auto",
			},
			-- 标签编辑器配置
			tag_editor = {
				kind = "auto",
			},
			-- 预览缓冲区配置
			preview_buffer = {
				kind = "floating_console",
			},
			-- 弹出窗口配置
			popup = {
				kind = "split",
			},
			-- Stash 视图配置
			stash = {
				kind = "tab",
			},
			-- 引用视图配置
			refs_view = {
				kind = "tab",
			},
			-- 标志配置
			signs = {
				hunk = { "", "" },
				item = { ">", "v" },
				section = { ">", "v" },
			},
			-- 插件集成配置
			integrations = {
				-- 使用 telescope 进行菜单选择
				telescope = nil,
				-- diffview 集成，显示传统差异视图
				diffview = nil,
				-- 使用 fzf-lua 进行菜单选择
				fzf_lua = nil,
				-- 使用 mini.pick 进行菜单选择
				mini_pick = nil,
			},
			-- 状态栏部分设置（如按需折叠/隐藏）
			sections = {
				sequencer = {
					folded = false,
					hidden = false,
				},
				untracked = {
					folded = false,
					hidden = false,
				},
				unstaged = {
					folded = false,
					hidden = false,
				},
				staged = {
					folded = false,
					hidden = false,
				},
				stashes = {
					folded = true,
					hidden = false,
				},
				unpulled_upstream = {
					folded = true,
					hidden = false,
				},
				unmerged_upstream = {
					folded = false,
					hidden = false,
				},
				unpulled_pushRemote = {
					folded = true,
					hidden = false,
				},
				unmerged_pushRemote = {
					folded = false,
					hidden = false,
				},
				recent = {
					folded = true,
					hidden = false,
				},
				rebase = {
					folded = true,
					hidden = false,
				},
			},
		})
		vim.keymap.set("n", "<leader>go", "<cmd>Neogit<cr>", { silent = true, desc = "Neogit" })
		vim.keymap.set("n", "<leader>gc", "<cmd>Neogit commit<cr>", { silent = true, desc = "Neogit commit" })
	end,
}
