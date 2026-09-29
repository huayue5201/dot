-- https://github.com/smart-splits-nvim/smart-splits.nvim

return {
	"smart-splits-nvim/smart-splits.nvim",
	version = "^3.0.0", -- 锁定 v3 大版本，比 branch = "v3" 更稳定
	-- 注意：tmux 集成依赖插件在「加载时」设置 pane 级变量 @pane-is-vim，
	-- 所以这里刻意不懒加载（不用 keys/event），保证 Neovim 启动即注册。
	config = function()
		local ss = require("smart-splits")

		ss.setup({
			log = { file = false }, -- v3 默认会写日志文件，这里关掉
			multiplexer_integration = "tmux", -- 显式启用 tmux 集成（自动探测可能因 $TERM_PROGRAM=ghostty 失败）
			disable_multiplexer_nav_when_zoomed = true, -- 当前 tmux 面板放大时不做跳转
		})

		local map = vim.keymap.set

		-- 移动光标到相邻窗口（Alt+hjkl，最高频）
		map("n", "<A-h>", ss.move_cursor_left, { desc = "Smart-splits: 光标去左窗口" })
		map("n", "<A-j>", ss.move_cursor_down, { desc = "Smart-splits: 光标去下窗口" })
		map("n", "<A-k>", ss.move_cursor_up, { desc = "Smart-splits: 光标去上窗口" })
		map("n", "<A-l>", ss.move_cursor_right, { desc = "Smart-splits: 光标去右窗口" })

		-- 调整窗口大小（<A-HJKL> = Alt+Shift+hjkl，匹配 ghostty 协议）
		map("n", "<A-H>", ss.resize_left, { desc = "Smart-splits: 左边界左移(变宽)" })
		map("n", "<A-J>", ss.resize_down, { desc = "Smart-splits: 下边界下移(变高)" })
		map("n", "<A-K>", ss.resize_up, { desc = "Smart-splits: 上边界上移(变高)" })
		map("n", "<A-L>", ss.resize_right, { desc = "Smart-splits: 右边界右移(变宽)" })

		-- 交换窗口 buffer（<leader><leader> + hjkl）
		map("n", "<leader><leader>h", ss.swap_buf_left, { desc = "Smart-splits: 与左窗口换 buffer" })
		map("n", "<leader><leader>j", ss.swap_buf_down, { desc = "Smart-splits: 与下窗口换 buffer" })
		map("n", "<leader><leader>k", ss.swap_buf_up, { desc = "Smart-splits: 与上窗口换 buffer" })
		map("n", "<leader><leader>l", ss.swap_buf_right, { desc = "Smart-splits: 与右窗口换 buffer" })
	end,
}
