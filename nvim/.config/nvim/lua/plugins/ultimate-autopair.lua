-- https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	event = { "InsertEnter", "CmdlineEnter" },
	config = function()
		-- 设置 ultimate-autopair 插件
		require("ultimate-autopair").setup({
			bs = { -- 删除光标前的字符
				enable = true, -- 启用删除光标前字符功能
				map = "<bs>", -- 设置删除键的映射
				cmap = "<bs>", -- 设置命令行模式下删除键的映射
				overjumps = true, -- 光标跳过配对字符
				space = true, -- 在配对字符之间留出空格
				indent_ignore = true, -- 忽略缩进
				single_delete = true, -- 单个字符删除
				conf = {}, -- 包含扩展配置
				multi = false, -- 使用多个配置
			},
			fastwarp = { -- 快速跳转
				enable = true, -- 启用快速跳转功能
				enable_normal = true, -- 启用正常模式下的快速跳转
				enable_reverse = true, -- 启用反向模式下的快速跳转
				hopout = false, -- 跳出配对字符
				map = "<A-e>", -- 设置快速跳转键的映射
				rmap = "<A-E>", -- 设置反向快速跳转键的映射
				cmap = "<A-e>", -- 设置命令行模式下快速跳转键的映射
				rcmap = "<A-E>", -- 设置命令行模式下反向快速跳转键的映射
				multiline = true, -- 多行跳转
				nocursormove = true, -- 光标不移动
				do_nothing_if_fail = true, -- 快速跳转失败不插入字符
				no_filter_nodes = { "string", "raw_string", "string_literals", "character_literal" }, -- 跳过过滤节点
				faster = false, -- 只启用跳过配对字符和转到末尾/下一行
				conf = {}, -- 包含扩展配置
				multi = false, -- 使用多个配置
			},
			close = { -- 插入配对字符
				enable = true, -- 启用插入配对字符功能
				map = "<A-)>", -- 设置插入配对字符键的映射
				cmap = "<A-)>", -- 设置命令行模式下插入配对字符键的映射
				conf = {}, -- 包含扩展配置
				multi = false, -- 使用多个配置
				do_nothing_if_fail = true, -- 插入失败不插入字符
			},
			space2 = { -- 插入匹配字符后的空格
				enable = true, -- 启用插入匹配字符后的空格功能
				match = [[\k]], -- 触发匹配字符的字符集
				conf = {}, -- 包含扩展配置
				multi = false, -- 使用多个配置
			},
			tabout = { -- 插入模式光标跳出符号
				enable = true, -- 启用插入模式光标跳出符号功能
				map = "<A-tab>", -- 设置插入模式光标跳出符号键的映射
				cmap = "<A-tab>", -- 设置命令行模式下插入模式光标跳出符号键的映射
				conf = {}, -- 包含扩展配置
				multi = false, -- 使用多个配置
				hopout = true, -- 跳出配对字符
				do_nothing_if_fail = true, -- 插入失败不插入字符
			},
		})
	end,
}
