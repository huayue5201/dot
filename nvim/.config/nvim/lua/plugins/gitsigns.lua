-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
	config = function()
		require("gitsigns").setup({
			signs = {
				add = { text = "┃" },
				change = { text = "┃" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
				untracked = { text = "┆" },
			},
			signs_staged = {
				add = { text = "┃" },
				change = { text = "┃" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
				untracked = { text = "┆" },
			},
			signs_staged_enable = true,
			signcolumn = true,
			numhl = false,
			linehl = false,
			word_diff = false,
			watch_gitdir = { follow_files = true },
			auto_attach = true,
			attach_to_untracked = false,
			current_line_blame = false,
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol",
				delay = 1000,
				ignore_whitespace = false,
				virt_text_priority = 100,
				use_focus = true,
			},
			current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
			sign_priority = 100,
			update_debounce = 100,
			status_formatter = nil,
			max_file_length = 40000,
			preview_config = {
				border = "single",
				style = "minimal",
				relative = "cursor",
				row = 0,
				col = 1,
			},
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")

				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts)
				end

				-- Navigation (导航)
				-- map("n", "]h", function()
				-- 	if vim.wo.diff then
				-- 		vim.cmd.normal({ "]h", bang = true })
				-- 	else
				-- 		gitsigns.nav_hunk("next")
				-- 	end
				-- end, { desc = "gitsigns：跳转到下一个差异区块" })
				--
				-- map("n", "[h", function()
				-- 	if vim.wo.diff then
				-- 		vim.cmd.normal({ "[h", bang = true })
				-- 	else
				-- 		gitsigns.nav_hunk("prev")
				-- 	end
				-- end, { desc = "gitsigns：跳转到上一个差异区块" })

				-- Actions (操作)
				map("n", "<leader>gs", gitsigns.stage_hunk, { desc = "gitsigns：暂存当前差异区块" })
				map("n", "<leader>gr", gitsigns.reset_hunk, { desc = "gitsigns：重置当前差异区块" })

				map("v", "<leader>gs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "gitsigns：暂存选中的差异区块" })

				map("v", "<leader>gr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "gitsigns：重置选中的差异区块" })

				map("n", "<leader>gS", gitsigns.stage_buffer, { desc = "gitsigns：暂存整个文件的差异" })
				map("n", "<leader>gR", gitsigns.reset_buffer, { desc = "gitsigns：重置整个文件的差异" })
				map("n", "<leader>glp", gitsigns.preview_hunk, { desc = "gitsigns：预览当前差异区块" })
				map(
					"n",
					"<leader>gli",
					gitsigns.preview_hunk_inline,
					{ desc = "gitsigns：内联预览当前差异区块" }
				)

				map("n", "<leader>glb", function()
					gitsigns.blame_line({ full = true })
				end, { desc = "gitsigns：显示当前行的 Git blame" })

				-- map("n", "<leader>gdx", gitsigns.diffthis, { desc = "gitsigns：显示当前文件的差异" })
				--
				-- map("n", "<leader>gD", function()
				-- 	gitsigns.diffthis("~")
				-- end, { desc = "gitsigns：显示与最后提交的差异" })

				map("n", "<leader>gQ", function()
					gitsigns.setqflist("all")
				end, { desc = "gitsigns：将所有差异添加到快速修复列表" })
				map("n", "<leader>gq", gitsigns.setqflist, { desc = "gitsigns：将差异添加到快速修复列表" })

				-- Toggles (切换)
				map(
					"n",
					"<leader>gtb",
					gitsigns.toggle_current_line_blame,
					{ desc = "gitsigns：切换当前行的 Git blame" }
				)
				map("n", "<leader>gtr", gitsigns.toggle_deleted, { desc = "gitsigns：切换显示删除的行" })
				map(
					"n",
					"<leader>gtw",
					gitsigns.toggle_word_diff,
					{ desc = "gitsigns：切换显示单词级别的差异" }
				)

				map("n", "<leader>glb", "<cmd>Gitsigns blame<cr>", { desc = "gitsigns：显示 Git blame" })

				-- Text object (文本对象)
				map({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "gitsigns：选择当前差异区块" })
			end,
		})
	end,
}
