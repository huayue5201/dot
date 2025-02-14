-- https://github.com/altermo/ultimate-autopair.nvim

vim.g.later(function()
	vim.g.add({ source = "altermo/ultimate-autopair.nvim" })

	require("ultimate-autopair").setup({
		-- 后退键配置
		bs = {
			enable = true, -- 启用后退键功能
			map = "<bs>", -- 后退键的映射
			cmap = "<bs>", -- 命令行模式下的后退键映射
			overjumps = true, -- 启用超越配对符号的删除功能
			space = true, -- 是否允许删除包含空格的配对符号，设置为 'balance' 时会平衡左右空格
			indent_ignore = false, -- 是否忽略缩进
			single_delete = false, -- 启用单个删除，防止删除不需要的内容
			conf = {}, -- 扩展配置
			multi = false, -- 是否支持多个配置
		},

		-- 回车键配置
		cr = {
			enable = true, -- 启用回车键功能
			map = "<cr>", -- 回车键的映射
			autoclose = false, -- 是否自动关闭配对符号
			conf = {
				cond = function(fn)
					return not fn.in_lisp() -- 如果在 Lisp 中，则不启用此功能
				end,
			},
			multi = false, -- 是否支持多个配置
		},

		-- 空格键配置
		space = {
			enable = true, -- 启用空格键功能
			map = " ", -- 空格键的映射
			cmap = " ", -- 命令行模式下的空格键映射
			check_box_ft = { "markdown", "vimwiki", "org" }, -- 对应特定文件类型启用勾选框功能
			_check_box_ft2 = { "norg" }, -- 可能会移除
			conf = {}, -- 扩展配置
			multi = false, -- 是否支持多个配置
		},

		-- 第二个空格键配置
		space2 = {
			enable = false, -- 禁用此功能
			match = [[\k]], -- 使用什么字符激活空格2功能
			conf = {}, -- 扩展配置
			multi = false, -- 是否支持多个配置
		},

		-- 快速跳转配置
		fastwarp = {
			enable = true, -- 启用快速跳转功能
			enable_normal = true, -- 启用普通模式的跳转
			enable_reverse = true, -- 启用反向跳转
			hopout = false, -- 不启用跳出括号
			map = "<A-e>", -- 快速跳转的映射
			rmap = "<A-E>", -- 反向快速跳转的映射
			cmap = "<A-e>", -- 命令行模式下的快速跳转映射
			rcmap = "<A-E>", -- 命令行模式下的反向快速跳转映射
			multiline = true, -- 是否支持跨多行跳转
			nocursormove = true, -- 禁用光标移动
			do_nothing_if_fail = true, -- 如果跳转失败，不插入字符
			no_filter_nodes = { "string", "raw_string", "string_literals", "character_literal" }, -- 跳过哪些节点
			faster = false, -- 仅启用跳过配对符号的功能
			conf = {}, -- 扩展配置
			multi = false, -- 是否支持多个配置
		},

		-- 关闭配对符号的配置
		close = {
			enable = true, -- 启用关闭配对符号功能
			map = "<A-)>", -- 关闭配对符号的映射
			cmap = "<A-)>", -- 命令行模式下的关闭配对符号映射
			do_nothing_if_fail = true, -- 如果关闭失败，则不插入配对符号
		},

		-- 跳出括号的配置
		tabout = {
			enable = true, -- 启用跳出括号功能
			map = "<A-tab>", -- 跳出括号的映射
			cmap = "<A-tab>", -- 命令行模式下的跳出括号映射
			conf = {}, -- 扩展配置
			multi = false, -- 是否支持多个配置
			hopout = true, -- 是否跳出括号
			do_nothing_if_fail = true, -- 如果跳出失败，不插入制表符
		},

		-- 扩展功能配置
		extensions = {
			cmdtype = { skip = { "/", "?", "@", "-" }, p = 100 }, -- 跳过特定命令类型
			filetype = { p = 90, nft = { "TelescopePrompt" }, tree = true }, -- 对特定文件类型启用扩展
			escape = { filter = true, p = 80 }, -- 过滤转义字符
			utf8 = { p = 70 }, -- 处理 UTF-8 字符
			tsnode = {
				p = 60, -- 类型过滤配置
				separate = {
					"comment",
					"string",
					"char",
					"character",
					"raw_string", -- 可根据需要调整
				},
			},
			cond = { p = 40, filter = true }, -- 条件过滤配置
			alpha = { p = 30, filter = false, all = false }, -- Alpha 过滤
			suround = { p = 20 }, -- 配对括号的扩展
			fly = { p = 10 }, -- 扩展跳跃操作
		},

		-- 配对符号配置
		internal_pairs = {
			{ "[", "]", fly = true, dosuround = true, newline = true, space = true }, -- 配对括号 [ ]
			{ "(", ")", fly = true, dosuround = true, newline = true, space = true }, -- 配对括号 ( )
			{ "{", "}", fly = true, dosuround = true, newline = true, space = true }, -- 配对括号 { }
			{ '"', '"', suround = true, multiline = false }, -- 配对双引号 " "
			{
				"'",
				"'",
				suround = true,
				cond = function(fn)
					return not fn.in_lisp() or fn.in_string()
				end,
				alpha = true,
				nft = { "tex" },
				multiline = false,
			}, -- 配对单引号 ' '
			{
				"`",
				"`",
				cond = function(fn)
					return not fn.in_lisp() or fn.in_string()
				end,
				nft = { "tex" },
				multiline = false,
			}, -- 配对反引号 ` `
			{ "``", "''", ft = { "tex" } }, -- 配对两个反引号 `` ''
			{ "```", "```", newline = true, ft = { "markdown" } }, -- 配对三个反引号 ``` ```
			{ "<!--", "-->", ft = { "markdown", "html" }, space = true }, -- 配对 HTML 注释 <!-- -->
			{ '"""', '"""', newline = true, ft = { "python" } }, -- 配对三引号 """ """
			{ "'''", "'''", newline = true, ft = { "python" } }, -- 配对三引号 ''' '''
		},

		-- 内部配对符号配置（可以自定义）
		config_internal_pairs = {
			-- 例如配置成 {'{', '}', suround = true}
		},
	})
end)
