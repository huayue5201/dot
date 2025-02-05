-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
	config = function()
		-- 配置 gitsigns 插件
		require("gitsigns").setup({
			on_attach = function(bufnr)
				local gitsigns = package.loaded.gitsigns -- 加载 gitsigns 模块

				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts) -- 设置键盘映射
				end

				-- Navigation
				map("n", "]h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]h", bang = true })
					else
						gitsigns.nav_hunk("next")
					end
				end)
				map("n", "[h", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[h", bang = true })
					else
						gitsigns.nav_hunk("prev")
					end
				end)

				map("n", "<leader>hs", gitsigns.stage_buffer, { desc = "暂存更改" })
				map("v", "<leader>hs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "暂存更改" })
				map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "暂存所有更改" })

				map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "取消更改" })
				map("v", "<leader>hr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "取消更改" })
				map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "取消所有更改" })

				map("n", "<leader>hu", gitsigns.undo_stage_hunk, { desc = "撤销上次更改" })

				map("n", "<leader>hb", function()
					gitsigns.blame_line({ full = true })
				end, { desc = "查看提交信息" })

				map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "查看改动" })

				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "选中hunk" })
			end,
		})
	end,
}
