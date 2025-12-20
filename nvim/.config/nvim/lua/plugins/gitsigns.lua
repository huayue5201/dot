-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
	config = function()
		local gitsigns = require("gitsigns")
		gitsigns.setup({
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol",
				delay = 1000,
				ignore_whitespace = false,
				virt_text_priority = 100,
				use_focus = true,
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
				map("n", "<leader>gs", gitsigns.stage_hunk, { desc = "gitsigns：暂存当前差异区块" })
				map("v", "<leader>gs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "gitsigns：暂存选中的差异区块" })
				map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "gitsigns：暂存整个缓冲区" })
				map("n", "<leader>gr", gitsigns.reset_hunk, { desc = "gitsigns：重置当前差异区块" })
				map("v", "<leader>gr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "gitsigns：重置选中的差异区块" })
				map("n", "<leader>gR", gitsigns.reset_buffer, { desc = "gitsigns：重置整个缓冲区" })
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
	end,
}
