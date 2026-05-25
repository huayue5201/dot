-- https://github.com/2kabhishek/markit.nvim
-- markit.nvim 是一个增强的标记管理插件，支持可视化标记、书签分组等功能

return {
	"2kabhishek/markit.nvim",
	dependencies = { "2kabhishek/pickme.nvim", "nvim-lua/plenary.nvim" },
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("markit").setup({
			-- 是否启用完整的默认快捷键绑定，默认 true
			add_default_keybindings = true,
			-- 显示哪些内置标记，默认 {}
			builtin_marks = {},
			-- 光标移动时是否在缓冲区首尾间循环，默认 true
			cyclic = true,
			-- 修改大写标记后是否更新 shada 文件，默认 false
			force_write_shada = false,
			-- 刷新标记显示的间隔时间（毫秒）
			-- 值越高性能越好但可能造成视觉延迟，
			-- 值越低可能影响性能，默认 150
			refresh_interval = 150,
			-- 各类标记在符号列（sign column）的优先级
			-- 可分别为不同类型设置，或设置一个数字应用到所有标记
			-- 默认 10
			sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
			-- 禁用标记跟踪的文件类型列表，默认 {}
			excluded_filetypes = {},
			-- 禁用标记跟踪的缓冲区类型列表，默认 {}
			excluded_buftypes = {},
			-- 是否启用书签系统，禁用可提升启动性能，默认 true
			enable_bookmarks = true,
			-- 书签组配置（仅在 enable_bookmarks = true 时生效）
			bookmarks = {
				{
					sign = "⚑", -- 符号列显示的图标（设为空字符串可禁用）
					-- virt_text = "hello", -- 行尾显示的虚拟文本
					annotate = true, -- 添加书签时是否提示输入注释
				},
				{ sign = "!", virt_text = "", annotate = false },
				{ sign = "@", virt_text = "", annotate = true },
			},
		})
	end,
}
