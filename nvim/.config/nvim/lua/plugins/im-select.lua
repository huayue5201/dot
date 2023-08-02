-- https://github.com/keaising/im-select.nvim
-- WARN:该插件依赖外部程序im-select
-- https://github.com/daipeihust/im-select

return {
	"keaising/im-select.nvim",
	event = "InsertEnter", -- keep for lazy loading
	opts = {
		-- 设置系统输入法,用im-select可检测当前系统输入法名称
		default_im_select = "com.apple.keylayout.ABC",
		-- im-select二进制名称或者完整可执行路径
		default_command = "im-select",
		-- 触发以下事件时，恢复默认输入法
		set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },
		-- 插入模式下恢复之前的输入模式
		set_previous_events = { "InsertEnter" },
		-- 系统缺失im-select可执行文件时，消息通知
		keep_quiet_on_no_binary = true,
	},
}
