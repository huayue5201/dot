-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
	dependencies = {
		"nvimtools/hydra.nvim",
	},
	config = function()
		local gitsigns = require("gitsigns")
		gitsigns.setup({
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
				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts)
				end

				-- Navigation (导航) - 保留基本导航
				map("n", "]h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]h", bang = true })
					else
						gitsigns.nav_hunk("next")
					end
				end, { desc = "gitsigns：跳转到下一个差异区块" })

				map("n", "[h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[h", bang = true })
					else
						gitsigns.nav_hunk("prev")
					end
				end, { desc = "gitsigns：跳转到上一个差异区块" })

				-- 仅保留最基础的操作，其他通过 Hydra 访问
				map("n", "<leader>gS", gitsigns.stage_hunk, { desc = "gitsigns：暂存当前差异区块" })

				map("v", "<leader>gs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "gitsigns：暂存选中的差异区块" })
				map("n", "<leader>gr", gitsigns.reset_hunk, { desc = "gitsigns：重置当前差异区块" })
				map("v", "<leader>gr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end)
				map("n", "<leader>gR", gitsigns.reset_buffer)
				map("n", "<leader>glb", function()
					gitsigns.blame_line({ full = true })
				end, { desc = "gitsigns：显示当前行的 Git blame" })

				-- Toggles (切换) - 保留切换功能
				map(
					"n",
					"<leader>gtb",
					gitsigns.toggle_current_line_blame,
					{ desc = "gitsigns：切换当前行的 Git blame" }
				)

				map(
					"n",
					"<leader>gtw",
					gitsigns.toggle_word_diff,
					{ desc = "gitsigns：切换显示单词级别的差异" }
				)

				map("n", "<leader>gb", "<cmd>Gitsigns blame<cr>", { desc = "gitsigns：显示 Git blame" })
				-- Text object (文本对象)
				map({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "gitsigns：选择当前差异区块" })
			end,
		})

		local Hydra = require("hydra")
		local hint = [[
 _J_: next hunk       _s_: stage hunk        _d_: preview inline   _b_: blame line
 _K_: prev hunk       _u_: reset hunk        _p_: preview hunk     _B_: blame full
 _R_: reset buffer    _S_: stage buffer      _/_: show base file
                      ^ ^                    ^ ^
 ^
 ^ ^                  _<Enter>_: Neogit              _q_: exit
]]

		Hydra({
			name = "Git",
			hint = hint,
			config = {
				color = "pink",
				invoke_on_body = true,
				hint = {
					float_opts = { border = "rounded" },
				},
				on_enter = function()
					-- 保存光标位置和折叠状态
					hydra_state = {
						cursor = vim.api.nvim_win_get_cursor(0),
						modifiable = vim.bo.modifiable,
						foldenable = vim.wo.foldenable,
					}

					vim.bo.modifiable = false
					gitsigns.toggle_signs(true)
					gitsigns.toggle_linehl(true)

					-- 打开所有折叠以便查看更改
					vim.cmd("silent! normal! zR")
				end,
				on_exit = function()
					-- 恢复光标位置
					if hydra_state and hydra_state.cursor then
						vim.api.nvim_win_set_cursor(0, hydra_state.cursor)
					end

					-- 恢复 modifiable 状态
					if hydra_state and hydra_state.modifiable ~= nil then
						vim.bo.modifiable = hydra_state.modifiable
					end

					-- 恢复折叠状态
					if hydra_state and hydra_state.foldenable ~= nil then
						vim.wo.foldenable = hydra_state.foldenable
					end

					-- 展开当前行的折叠
					vim.cmd("normal! zv")

					gitsigns.toggle_signs(false)
					gitsigns.toggle_linehl(false)

					-- 清除临时状态
					hydra_state = nil
				end,
			},
			mode = { "n", "x" },
			body = "<leader>gh",
			heads = {
				{
					"J",
					function()
						if vim.wo.diff then
							return "]c"
						end
						vim.schedule(function()
							gitsigns.nav_hunk("next")
						end)
						return "<Ignore>"
					end,
					{ expr = true, desc = "next hunk" },
				},
				{
					"K",
					function()
						if vim.wo.diff then
							return "[c"
						end
						vim.schedule(function()
							gitsigns.nav_hunk("prev")
						end)
						return "<Ignore>"
					end,
					{ expr = true, desc = "prev hunk" },
				},
				{ "s", gitsigns.stage_hunk, { desc = "stage hunk" } },
				{
					"u",
					function()
						gitsigns.reset_hunk()
					end,
					{ desc = "reset hunk" },
				},
				{ "S", gitsigns.stage_buffer, { desc = "stage buffer" } },
				{ "p", gitsigns.preview_hunk, { desc = "preview hunk" } },
				{
					"d",
					function()
						gitsigns.preview_hunk_inline()
					end,
					{ nowait = true, desc = "preview hunk inline" },
				},
				{ "b", gitsigns.blame_line, { desc = "blame" } },
				{
					"B",
					function()
						gitsigns.blame_line({ full = true })
					end,
					{ desc = "blame show full" },
				},
				{ "/", gitsigns.show, { exit = true, desc = "show base file" } },
				{ "<Enter>", "<Cmd>Neogit<CR>", { exit = true, desc = "Neogit" } },
				{ "q", nil, { exit = true, nowait = true, desc = "exit" } },
				{
					"R",
					function()
						gitsigns.reset_buffer()
					end,
					{ desc = "reset buffer" },
				},
			},
		})
	end,
}
