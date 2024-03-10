-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre" },
	config = function()
		-- 配置 gitsigns 插件
		require("gitsigns").setup({
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns -- 加载 gitsigns 模块

				local function map(mode, l, r, opts)
					opts = opts or {}
					opts.buffer = bufnr
					vim.keymap.set(mode, l, r, opts) -- 设置键盘映射
				end

				-- 导航
				map("n", "]g", function()
					if vim.wo.diff then -- 如果当前窗口是 diff 窗口
						return "]g"
					end
					vim.schedule(function()
						gs.next_hunk() -- 跳转到下一个 hunk
					end)
					return "<Ignore>"
				end, { desc = "跳转到下一处改动" }, { expr = true })

				map("n", "[g", function()
					if vim.wo.diff then -- 如果当前窗口是 diff 窗口
						return "[g"
					end
					vim.schedule(function()
						gs.prev_hunk() -- 跳转到上一个 hunk
					end)
					return "<Ignore>"
				end, { desc = "跳转到上一处改动" }, { expr = true })

				-- 操作
				map("n", "<leader>gs", gs.stage_hunk, { desc = "提交当前改动" })
				map("v", "<leader>gs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) -- 选中区域提交
				end)
				map("n", "<leader>gS", gs.stage_buffer, { desc = "提交buffer内所有改动" })
				map("n", "<leader>gr", gs.reset_hunk, { desc = "重置当次改动" })
				map("v", "<leader>gr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) -- 选中区域重置
				end)
				map("n", "<leader>gR", gs.reset_buffer, { desc = "重置buffer内所有改动" })
				map("n", "<leader>gu", gs.undo_stage_hunk, { desc = "撤销提交" })
				map("n", "<leader>gp", gs.preview_hunk, { desc = "浮窗查看光标下改动" })
				-- 浮窗查看提交信息
				map("n", "<leader>gb", function()
					gs.blame_line({ full = true }) -- 查看光标所在行的 blame 信息
				end, { desc = "浮窗查看提交信息" })

				-- 文本对象
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>") -- 选中当前 hunk
			end,
		})
	end,
}
