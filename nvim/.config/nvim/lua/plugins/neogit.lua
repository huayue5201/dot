-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	dependencies = {
		"esmuellert/codediff.nvim",
		"m00qek/baleia.nvim",
	},
	keys = {
		{ "<leader>hg", "<cmd>Neogit<cr>", desc = "neogit: Open Neogit" },
		{
			"<leader>hc",
			function()
				if vim.bo.filetype == "gitcommit" then
					require("neogit-ai-commit").generate_commit_message(vim.api.nvim_get_current_buf())
					return
				end
				-- 直接打开 neogit 的 commit 编辑器（等价于状态页里 c c，不经过 popup）。
				-- 两个坑：(1) client.wrap 必须在 async 上下文里调用；
				-- (2) 冷启动时 repo state 还没算过（hooks 等字段是 nil），先 refresh 一次。
				local a = require("neogit.lib.async")
				local git = require("neogit.lib.git")
				a.void(function()
					git.repo:refresh({
						source = "neogit-commit-keymap",
						callback = function()
							a.void(function()
								require("neogit.client").wrap(git.cli.commit.arg_list({}), {
									interactive = true,
									autocmd = "NeogitCommitComplete",
									show_diff = require("neogit.config").values.commit_editor.show_staged_diff,
									msg = { success = "Committed", fail = "Commit failed" },
								})
							end)()
						end,
					})
				end)()
			end,
			desc = "neogit: 生成/编辑提交信息",
		},
	},
	config = function()
		local neogit = require("neogit")
		neogit.setup({
			treesitter_diff_highlight = true,
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
		})

		-- vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Open Neogit UI" })
	end,
}
