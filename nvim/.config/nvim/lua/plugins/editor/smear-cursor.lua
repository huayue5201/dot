-- https://github.com/sphamba/smear-cursor.nvim
--
-- 光标"拖影"动画（类似 Neovide 的 animated cursor，纯终端可行）。
-- 和 neoscroll 的分工：neoscroll 动的是窗口视口，这个动的是光标本身。
-- 注意它挂了 CursorMoved/WinScrolled/ModeChanged + vim.on_key，是有常驻成本的插件；
-- 手感不对用 :SmearCursorToggle 一键关。
--
-- 配合改动：neoscroll 的 hide_cursor 已设为 false——两个插件都改 'guicursor'，
-- neoscroll 会整串覆盖再还原，滚动期间容易把 smear 的隐藏组冲掉（甚至还原失败
-- 导致真光标一直不可见），让 smear 自己管光标显示更稳。

return {
	"sphamba/smear-cursor.nvim",
	config = function()
		require("smear_cursor").setup({
			smear_between_buffers = true, -- 切 buffer/窗口也拖影
			smear_between_neighbor_lines = true, -- 相邻行/同行移动也拖影
			scroll_buffer_space = true, -- 滚动时按 buffer 空间画，避免拖影停在屏幕上
			smear_to_cmd = true, -- 进出命令行模式也拖影
			vertical_bar_cursor = false, -- 普通模式是方块光标
			-- 字体没有 legacy computing symbols（方块/半块 Unicode）时保持 false，
			-- 有的话（如 Cascadia Code）改 true 会细腻很多
			legacy_computing_symbols_support = true,

			-- 手感：默认 0.6/0.45 偏拖沓，调快一点更跟手
			stiffness = 0.7, -- 头部追赶速度
			trailing_stiffness = 0.6, -- 尾部追赶速度
			stiffness_insert_mode = 0.7,
			trailing_stiffness_insert_mode = 0.7,
			distance_stop_animating_vertical_bar = 0.3, -- 插入模式早点收尾，不打字卡顿

			time_interval = 17, -- 帧间隔 ms（≈60fps）
			particles_enabled = true, -- 粒子特效，开了更炫但更耗 CPU
		})
	end,
}
