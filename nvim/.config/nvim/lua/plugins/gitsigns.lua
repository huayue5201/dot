-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
	config = function()
		local gitsigns = require("gitsigns")
		gitsigns.setup({
			signs = {
				add = { text = "┃" }, -- 添加的行显示为 '┃'
				change = { text = "┃" }, -- 修改的行显示为 '┃'
				delete = { text = "_" }, -- 删除的行显示为 '_'
				topdelete = { text = "‾" }, -- 顶部删除的行显示为 '‾'
				changedelete = { text = "~" }, -- 修改和删除的行显示为 '~'
				untracked = { text = "┆" }, -- 未追踪的文件显示为 '┆'
			},
			signs_staged = {
				add = { text = "┃" }, -- 阶段区添加的行显示为 '┃'
				change = { text = "┃" }, -- 阶段区修改的行显示为 '┃'
				delete = { text = "_" }, -- 阶段区删除的行显示为 '_'
				topdelete = { text = "‾" }, -- 阶段区顶部删除的行显示为 '‾'
				changedelete = { text = "~" }, -- 阶段区修改和删除的行显示为 '~'
				untracked = { text = "┆" }, -- 阶段区未追踪的文件显示为 '┆'
			},
			signs_staged_enable = true, -- 启用阶段区标记
			signcolumn = true, -- 显示标记列，切换通过 `:Gitsigns toggle_signs`
			numhl = false, -- 禁用行号高亮，切换通过 `:Gitsigns toggle_numhl`
			linehl = false, -- 禁用整行高亮，切换通过 `:Gitsigns toggle_linehl`
			word_diff = false, -- 禁用字级别差异高亮，切换通过 `:Gitsigns toggle_word_diff`
			watch_gitdir = {
				follow_files = true, -- 监听 Git 目录中的文件变化
			},
			auto_attach = true, -- 自动附加 Git 目录中的文件
			attach_to_untracked = false, -- 不附加未追踪的文件
			current_line_blame = false, -- 禁用当前行 blame，切换通过 `:Gitsigns toggle_current_line_blame`
			current_line_blame_opts = {
				virt_text = true, -- 显示虚拟文本
				virt_text_pos = "eol", -- 虚拟文本位置设置为行尾 'eol'
				delay = 1000, -- 显示延迟 1000 毫秒
				ignore_whitespace = false, -- 不忽略空白字符
				virt_text_priority = 100, -- 虚拟文本优先级
				use_focus = true, -- 只有在焦点行时才显示
			},
			current_line_blame_formatter = "<author>, <author_time:%R> - <summary>", -- 当前行 blame 格式
			sign_priority = 100, -- 设置标记的优先级
			update_debounce = 100, -- 更新延迟时间 100 毫秒
			status_formatter = nil, -- 使用默认状态格式化
			max_file_length = 40000, -- 如果文件超过 40000 行，则禁用
			preview_config = {
				style = "minimal", -- 使用简洁的预览风格
				relative = "cursor", -- 相对位置设置为光标位置
				row = 0, -- 预览窗口的行
				col = 1, -- 预览窗口的列
			},

			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")

				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts)
				end

				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gitsigns.nav_hunk("next")
					end
				end, { desc = "Gitsigns: Next Hunk" })

				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gitsigns.nav_hunk("prev")
					end
				end, { desc = "Gitsigns: Previous Hunk" })

				-- Actions
				map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "Gitsigns: Stage Hunk" })
				map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "Gitsigns: Reset Hunk" })

				map("v", "<leader>hs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "Gitsigns: Stage Selected Hunk" })

				map("v", "<leader>hr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "Gitsigns: Reset Selected Hunk" })

				map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "Gitsigns: Stage Buffer" })
				map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "Gitsigns: Reset Buffer" })
				map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "Gitsigns: Preview Hunk" })
				map("n", "<leader>hi", gitsigns.preview_hunk_inline, { desc = "Gitsigns: Preview Hunk Inline" })

				map("n", "<leader>hb", function()
					gitsigns.blame_line({ full = true })
				end, { desc = "Gitsigns: Blame Line" })

				map("n", "<leader>hd", gitsigns.diffthis, { desc = "Gitsigns: Diff This" })
				map("n", "<leader>hD", function()
					gitsigns.diffthis("~")
				end, { desc = "Gitsigns: Diff This vs Previous" })

				map("n", "<leader>hQ", function()
					gitsigns.setqflist("all")
				end, { desc = "Gitsigns: Set QF List (All)" })
				map("n", "<leader>hq", gitsigns.setqflist, { desc = "Gitsigns: Set QF List (Hunks)" })

				-- Toggles
				map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "Gitsigns: Toggle Line Blame" })
				map("n", "<leader>tw", gitsigns.toggle_word_diff, { desc = "Gitsigns: Toggle Word Diff" })

				-- Text object
				map({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "Gitsigns: Select Hunk" })
			end,
		})
	end,
}
