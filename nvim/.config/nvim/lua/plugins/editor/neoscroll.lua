-- https://github.com/karb94/neoscroll.nvim
--
-- 滚动命令的平滑动画（<C-d>/<C-u>/<C-f>/<C-b>/<C-e>/<C-y>/zt/zz/zb）。
-- 为什么不用 cinnamon.nvim：它每帧 set_cursor 会触发 CursorMoved，本仓 statusline
-- 在 CursorMoved 上 enqueue 重绘（lua/ui/statusline.lua），逐帧重排状态栏会掉帧；
-- neoscroll 在动画期间 eventignore 掉 CursorMoved/WinScrolled，且不动 scrolloff。

return {
	"karb94/neoscroll.nvim",
	config = function()
		require("neoscroll").setup({
			-- 只接管这些键，其余移动/滚动保持原生零开销
			mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
			hide_cursor = true, -- 交给 smear-cursor.nvim：两者都写 'guicursor'，同时开会打架
			stop_eof = true, -- 到文件尾就停，不空转
			respect_scrolloff = true, -- 尊重全局 scrolloff=8，滚到边界仍留 8 行
			cursor_scrolls_alone = true, -- 窗口滚到头时光标继续走
			duration_multiplier = 1.0, -- 想整体调快/调慢改这里
			easing = "sine", -- 起停有加减速，比 linear 顺眼
			performance_mode = false, -- 默认关；大文件临时 :NeoscrollEnableGlobalPM
			ignored_events = { "WinScrolled", "CursorMoved" },
		})
	end,
}
