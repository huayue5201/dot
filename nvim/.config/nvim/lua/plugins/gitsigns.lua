-- https://github.com/lewis6991/gitsigns.nvim

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPost",
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
				map("n", "]h", function()
					if vim.wo.diff then -- 如果当前窗口是 diff 窗口
						return "]h"
					end
					vim.schedule(function()
						gs.next_hunk() -- 跳转到下一个 hunk
					end)
					return "<Ignore>"
				end, { desc = "跳转到下一处改动" }, { expr = true })

				map("n", "[h", function()
					if vim.wo.diff then -- 如果当前窗口是 diff 窗口
						return "[h"
					end
					vim.schedule(function()
						gs.prev_hunk() -- 跳转到上一个 hunk
					end)
					return "<Ignore>"
				end, { desc = "跳转到上一处改动" }, { expr = true })

				-- 操作
				map("n", "<leader>hr", gs.reset_hunk, { desc = "重置当次改动" })

				map("v", "<leader>hr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, { desc = "重置当次改动" })

				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "选中当前hunk" })
			end,
		})
	end,
}
