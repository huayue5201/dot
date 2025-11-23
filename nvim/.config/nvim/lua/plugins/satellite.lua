-- GitHub: https://github.com/lewis6991/satellite.nvim

return {
	"lewis6991/satellite.nvim",
	event = "UIEnter",
	config = function()
		require("satellite").setup({
			-- 只在当前窗口显示（如果你只想看到当前 buffer 的 scrollbar）
			current_only = false,
			-- 透明度 (winblend) 设置
			winblend = 50,
			-- Z 值 (层级)
			zindex = 40,
			-- 排除某些文件类型
			excluded_filetypes = {
				"help",
				"alpha", -- 例如 welcome 界面
				"neo-tree", -- 文件树类型 buffer
			},
			-- 滚动条宽度 (列宽)
			width = 2,

			-- 各种 handler (装饰器) 的设置
			handlers = {
				cursor = {
					enable = true,
					symbols = { "⎺", "⎻", "⎼", "⎽" }, -- 用这些字符表示光标滚动位置
				},
				search = {
					enable = true,
					-- 默认 highlight group 是 SatelliteSearch / SatelliteSearchCurrent
				},
				diagnostic = {
					enable = true,
					signs = { "-", "=", "≡" },
					-- 最低 severity 显示等级
					min_severity = vim.diagnostic.severity.HINT,
				},
				gitsigns = {
					enable = false,
					signs = {
						add = "│",
						change = "│",
						delete = "-",
					},
				},
				marks = {
					enable = true,
					show_builtins = false,
					key = "m", -- 用标记 m: marks
				},
				quickfix = {
					enable = true,
					signs = { "-", "=", "≡" },
				},
			},
		})
	end,
}
