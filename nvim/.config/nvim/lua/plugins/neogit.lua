-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	lazy = true,
	dependencies = {
		"nvim-lua/plenary.nvim", -- 必须
		"sindrets/diffview.nvim", -- 可选，用于 diff 视图
	},
	cmd = "Neogit",
	keys = {
		{ "<leader>gg", "<cmd>Neogit<cr>", desc = "neogit: Open Neogit" },
	},
	config = function()
		local neogit = require("neogit")
		neogit.setup({
			-- 窗口与布局
			kind = "split", -- 可选 "tab" | "split" | "vsplit" | "floating"

			-- "ascii"   is the graph the git CLI generates
			-- "unicode" is the graph like https://github.com/rbong/vim-flog
			-- "kitty"   is the graph like https://github.com/isakbm/gitgraph.nvim - use https://github.com/rbong/flog-symbols if you don't use Kitty
			graph_style = "kitty",
			-- Show message with spinning animation when a git command is running.
			process_spinner = false,
			-- Allows a different telescope sorter. Defaults to 'fuzzy_with_index_bias'. The example below will use the native fzf
			-- sorter instead. By default, this function returns `nil`.
			telescope_sorter = function()
				return require("telescope").extensions.fzf.native_fzf_sorter()
			end,

			commit_editor = {
				kind = "split",
				show_staged_diff = true, -- 在提交界面显示已暂存文件的 diff
				-- 可选值：
				-- "split"        将 diff 放在下面
				-- "vsplit"       将 diff 放在右侧
				-- "split_above"  diff 在提交编辑器上方
				-- "vsplit_left"  diff 在左侧
				-- "auto"         自动判断（80列以上右侧，否则下方）
				staged_diff_split_kind = "split", -- 选择 diff 显示方式：这里是 “下方”
				spell_check = true, -- 拼写检查（建议写英文 commit message 时开启）
			},

			commit_select_view = {
				kind = "tab", -- 在新的 tab 打开“选择 commit”界面（例如 reword/amend）
			},

			commit_view = {
				kind = "vsplit", -- 查看单个 commit 时：右侧打开详细信息
				verify_commit = vim.fn.executable("gpg") == 1,
				-- 若系统装了 gpg，则可验证 GPG 签名
			},

			log_view = {
				kind = "tab", -- log 界面：在新的 tab 打开
			},

			rebase_editor = {
				kind = "auto", -- 自动选择：宽屏 -> vsplit；窄屏 -> split
			},

			reflog_view = {
				kind = "tab", -- 查看 reflog：新 tab 打开
			},

			merge_editor = {
				kind = "auto", -- 自动选择 merge 冲突编辑布局
			},

			preview_buffer = {
				kind = "floating_console", -- 预览区使用浮动窗口（类似 console 风格）
			},

			popup = {
				kind = "split", -- 各种 popup 菜单（如 branch/checkout）打开方式：水平分屏
			},

			stash = {
				kind = "tab", -- stash 操作界面：新 tab 打开
			},

			refs_view = {
				kind = "tab", -- 分支/Tag 列表界面：新 tab 打开
			},

			signs = {
				-- 这些符号用在：
				-- section（一级菜单）、item（项目）、hunk（修改块）
				-- 左边第一个符号：折叠状态
				-- 第二个符号：展开状态
				hunk = { "", "" }, -- hunk 折叠/展开符号（这里设为空）
				item = { ">", "v" }, -- item 折叠时“>”，展开时“v”
				section = { ">", "v" }, -- section 同上
			},
		})
		-- vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Open Neogit UI" })
	end,
}
