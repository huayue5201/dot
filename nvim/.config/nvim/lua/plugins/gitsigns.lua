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

			signs_staged_enable = true,

			signcolumn = true,
			numhl = false,
			linehl = false,
			word_diff = false,

			watch_gitdir = { follow_files = true },
			auto_attach = true,
			attach_to_untracked = true,

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
			update_debounce = 200,
			max_file_length = 40000,

			preview_config = {
				style = "minimal",
				relative = "cursor",
				row = 0,
				col = 1,
			},

			on_attach = function(bufnr)
				local gs = require("gitsigns")

				local function map(mode, keys, func, desc)
					vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = desc })
				end

				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gs.nav_hunk("next")
					end
				end, "Next Hunk")

				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gs.nav_hunk("prev")
					end
				end, "Prev Hunk")

				-- Actions
				map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
				map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")

				map("v", "<leader>hs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Stage Selected Hunk")

				map("v", "<leader>hr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Reset Selected Hunk")

				map("n", "<leader>hS", gs.stage_buffer, "Stage Buffer")
				map("n", "<leader>hR", gs.reset_buffer, "Reset Buffer")

				map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
				map("n", "<leader>hi", gs.preview_hunk_inline, "Preview Hunk Inline")

				map("n", "<leader>hb", function()
					gs.blame_line({ full = true })
				end, "Blame Line")

				map("n", "<leader>hB", function()
					vim.cmd("Gitsigns blame")
				end, "QF Gitsigns blame")

				-- map("n", "<leader>hd", gs.diffthis, "Diff This")
				-- map("n", "<leader>hD", function()
				-- 	gs.diffthis("~")
				-- end, "Diff Previous")

				map("n", "<leader>hQ", function()
					gs.setqflist("all")
				end, "QF All Hunks")
				map("n", "<leader>hq", gs.setqflist, "QF Hunks")

				-- Toggles
				map("n", "<leader>tb", gs.toggle_current_line_blame, "Toggle Blame")
				map("n", "<leader>tw", gs.toggle_word_diff, "Toggle Word Diff")

				-- Text object
				map({ "o", "x" }, "ih", gs.select_hunk, "Select Hunk")
			end,
		})
	end,
}
