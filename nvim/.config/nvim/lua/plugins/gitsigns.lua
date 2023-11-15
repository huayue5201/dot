-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "VeryLazy", -- keep for lazy loading
	config = function()
		require("gitsigns").setup({
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns

				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts)
				end

				-- Navigation
				map("n", "]g", function()
					if vim.wo.diff then
						return "]g"
					end
					vim.schedule(function()
						gs.next_hunk()
					end)
					return "<Ignore>"
				end, { desc = "跳转到下一处改动" }, { expr = true })

				map("n", "[g", function()
					if vim.wo.diff then
						return "[g"
					end
					vim.schedule(function()
						gs.prev_hunk()
					end)
					return "<Ignore>"
				end, { desc = "跳转到上一处改动" }, { expr = true })

				-- Actions
				map("n", "<leader>gs", gs.stage_hunk, { desc = "提交当前改动" })
				map("v", "<leader>gs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end)
				map("n", "<leader>gS", gs.stage_buffer, { desc = "提交buffer内所有改动" })
				map("n", "<leader>gr", gs.reset_hunk, { desc = "重置当次改动" })
				map("v", "<leader>gr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end)
				map("n", "<leader>gR", gs.reset_buffer, { desc = "重置buffer内所有改动" })
				map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "撤销提交" })
				map("n", "<leader>gp", gs.preview_hunk, { desc = "浮窗查看光标下改动" })
				-- 浮窗查看提交信息
				map("n", "<leader>gb", function()
					gs.blame_line({ full = true })
				end, { desc = "浮窗查看提交信息" })

				-- Text object
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
			end,
		})
	end,
}
