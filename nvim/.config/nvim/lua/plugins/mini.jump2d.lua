-- https://github.com/nvim-mini/mini.jump2d

return {
	"nvim-mini/mini.jump2d",
	event = "VeryLazy", -- 延迟加载（在 VeryLazy 事件触发时加载）
	version = "*",
	config = function()
		require("mini.jump2d").setup({
			-- 不需要把这个表写在 `setup()` 里。插件会自动使用它。

			-- 生成跳转点（按字节索引）的函数，用于指定某一行。
			-- 更多信息请参阅 |MiniJump2d.start|。
			-- 如果为 `nil`（默认）—— 使用 |MiniJump2d.default_spotter|
			spotter = nil,

			-- 用于跳转点标签的字符（按提供的顺序使用）
			labels = "abcdefghijklmnopqrstuvwxyz",

			-- 视觉效果的选项
			view = {
				-- 是否对包含至少一个跳转点的行进行变暗处理
				dim = false,

				-- 提前显示多少步。设置成一个很大的数字即可显示所有步骤。
				n_steps_ahead = 0,
			},

			-- 用于计算跳转点的行
			allowed_lines = {
				blank = true, -- 空行（即使为 true，也不会传递给 spotter）
				cursor_before = true, -- 光标所在行之前的行
				cursor_at = true, -- 光标所在行
				cursor_after = true, -- 光标所在行之后的行
				fold = true, -- 折叠开始的行（即使为 true，也不会传递给 spotter）
			},

			-- 当前标签页中哪些窗口用于计算可见行
			allowed_windows = {
				current = true, -- 当前窗口
				not_current = false, -- 非当前窗口
			},

			-- 在特定事件执行的函数
			hooks = {
				before_start = nil, -- 跳转开始前执行
				after_jump = nil, -- 跳转实际完成后执行
			},

			-- 模块映射。使用 `''`（空字符串）可以禁用某个映射
			mappings = {
				start_jumping = "s",
			},

			-- 是否禁用非错误反馈提示
			-- 这也会影响在用户需要输入时，经过空闲时间后显示的（纯信息性）助手提示。
			silent = false,
		})
	end,
}
