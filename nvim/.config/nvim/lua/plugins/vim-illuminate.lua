-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate", -- 插件 GitHub 仓库地址
	event = { "BufReadPre", "BufNewFile" }, -- 触发插件配置的事件
	config = function()
		-- 默认配置
		require("illuminate").configure({
			-- 提供者：用于在缓冲区中获取引用的提供者，按优先级排序
			providers = {
				"lsp",
				"treesitter",
				"regex",
			},
			-- 延迟时间（毫秒）
			delay = 300,
			-- 文件类型的特定配置
			filetype_overrides = {},
			-- 不要高亮的文件类型列表，会覆盖 filetypes_allowlist
			filetypes_denylist = {
				"dirbuf",
				"dirvish",
				"fugitive",
			},
			-- 要高亮的文件类型列表，会被 filetypes_denylist 覆盖
			filetypes_allowlist = {},
			-- 不要高亮的模式列表，会覆盖 modes_allowlist
			modes_denylist = {},
			-- 要高亮的模式列表，会被 modes_denylist 覆盖
			modes_allowlist = {},
			-- 不要高亮的正则表达式语法列表，只适用于 'regex' 提供者
			providers_regex_syntax_denylist = {},
			-- 要高亮的正则表达式语法列表，会被 providers_regex_syntax_denylist 覆盖，只适用于 'regex' 提供者
			providers_regex_syntax_allowlist = {},
			-- 是否在光标下方高亮
			under_cursor = true,
			-- 大文件截断值：达到此行数将使用大文件配置
			-- 当达到此截断值时，under_cursor 选项将被禁用
			large_file_cutoff = nil,
			-- 大文件配置：用于大文件的配置（基于 large_file_cutoff）
			-- 支持与 .configure 中传递的相同键
			-- 如果为 nil，则大文件将禁用 vim-illuminate。
			large_file_overrides = nil,
			-- 执行高亮所需的最小匹配数量
			min_count_to_highlight = 1,
			-- 一个回调函数，用于启用/禁用光照的决定。这将经常调用，请不要在其中执行昂贵的操作。
			should_enable = function(bufnr)
				return true
			end,
			-- 设置正则表达式的大小写敏感性
			case_insensitive_regex = false,
		})
	end,
}
