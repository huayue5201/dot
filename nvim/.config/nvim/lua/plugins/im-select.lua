-- https://github.com/keaising/im-select.nvim

return {
	"keaising/im-select.nvim",
	event = "InsertEnter",
	config = function()
		require("im_select").setup({
			-- 在 `normal` 模式下，IM（输入法）会被设置为 `default_im_select`
			-- 对于 Windows/WSL，默认值： "1033"，即英文 US 键盘
			-- 对于 macOS，默认值： "com.apple.keylayout.ABC"，即美式键盘
			-- 对于 Linux，默认值：
			--               "keyboard-us" 用于 Fcitx5
			--               "1" 用于 Fcitx
			--               "xkb:us::eng" 用于 ibus
			-- 你可以使用 `im-select` 或 `fcitx5-remote -n` 来获取 IM 的名称
			default_im_select = "com.apple.keylayout.ABC",

			-- 可以是二进制文件的名称、二进制文件的完整路径，或者一个表，比如 'im-select'，
			-- '/usr/local/bin/im-select' 用于没有额外参数的二进制文件，
			-- 或者 { "AIMSwitcher.exe", "--imm" } 用于需要额外参数的二进制文件。
			-- 对于 Windows/WSL，默认值： "im-select.exe"
			-- 对于 macOS，默认值： "macism"
			-- 对于 Linux，默认值： "fcitx5-remote" 或 "fcitx-remote" 或 "ibus"
			default_command = "macism",

			-- 在以下事件触发时恢复默认的输入法状态
			set_default_events = { "VimEnter", "InsertLeave", "CmdlineLeave" },

			-- 在以下事件触发时恢复之前使用的输入法状态，
			-- 如果你不想在插入模式下恢复之前使用的输入法，可以将 `set_previous_events = {}` 留空
			set_previous_events = { "InsertEnter" },

			-- 当二进制文件缺失时，是否显示如何安装二进制文件的通知
			keep_quiet_on_no_binary = false,

			-- 是否异步运行 `default_command` 来切换输入法
			async_switch_im = true,
		})
	end,
}
