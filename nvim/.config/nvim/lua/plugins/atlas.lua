-- https://github.com/emrearmagan/atlas.nvim

return {
	"emrearmagan/atlas.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		-- 不需要 codediff：atlas 用自己的 AtlasDiff（见下面 pulls.diff.open_cmd），
		-- codediff 另有独立 spec（lua/plugins/codediff.lua）
	},
	config = function()
		require("atlas").setup({
			-- 必须配置 provider，否则 :Atlas 会提示 "No pulls providers configured"
			-- GitHub 走 gh CLI（已 gh auth login），如需关缓存可写 cache_ttl = 0
			providers = {
				github = {},
			},
			pulls = {
				delete_notes = false,
				default_merge_method = "merge",
				default_delete_source_branch = false,
				git_transport = "https",

				comment_templates = {
					insert_mode = true,
					items = {
						{ label = "Suggestion", text = "suggestion: " },
						{ label = "Issue", text = "issue: " },
						{ label = "Nitpick", text = "nitpick: " },
					},
				},

				diff = {
					open_cmd = "AtlasDiff",
					comment_display = "virtual_lines",
					review_panel = {
						hidden = true,
						height = 10,
					},
					layout = "inline",
					compact = true,
					lsp = {
						enabled = false,
						dir = nil,
						link = {},
					},
					explorer = {
						grouped = true,
						hidden = false,
						show_commits = false,
						width = 40,
						initial_focus = "explorer",
						preview = false,
						ignore = { ".git/**", ".jj/**" },
					},
				},

				repo_config = {
					paths = {
						["huayue5201/*"] = "~/neovim-plugins/*",
					},
					settings = {},
				},

				custom_actions = {},
			},
		})

		vim.keymap.set("n", "<leader>ha", "<cmd>Atlas<cr>", { desc = "Atlas" })
	end,
}
