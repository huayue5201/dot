-- https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	event = { "InsertEnter", "CmdlineEnter" },
	config = function()
		require("ultimate-autopair").setup({
			map = true, -- 在插入模式启用映射[citation:1]
			cmap = true, -- 在命令行模式启用映射[citation:1]
			pair_map = true, -- 启用配对的映射
			pair_cmap = true, -- 在命令行启用配对的映射
			multiline = true, -- 启用多行配对支持[citation:2]

			-- 内置配对规则配置[citation:1]
			internal_pairs = {
				-- 基础括号类，启用fly模式、包围、回车扩展和空格扩展
				{ "[", "]", fly = true, dosuround = true, newline = true, space = true },
				{ "(", ")", fly = true, dosuround = true, newline = true, space = true },
				{ "{", "}", fly = true, dosuround = true, newline = true, space = true },

				-- 引号类，支持包围但不支持多行（根据语言习惯调整）
				{ '"', '"', suround = true, multiline = false },
				{ "'", "'", suround = true, multiline = false },
				{ "`", "`", suround = true, multiline = false },

				-- 语言特定配对规则
				{ "<!--", "-->", ft = { "markdown", "html" }, space = true }, -- Markdown和HTML注释
				{ "```", "```", newline = true, ft = { "markdown" } }, -- Markdown代码块
				{ '"""', '"""', newline = true, ft = { "python" } }, -- Python多行字符串
				{ "'''", "'''", newline = true, ft = { "python" } }, -- Python多行字符串
			},

			-- 扩展功能配置
			extensions = {
				-- 文件类型处理：在指定文件类型中禁用，支持treesitter
				filetype = { p = 90, nft = { "TelescopePrompt" }, tree = true },

				-- 转义字符处理
				escape = { filter = true, p = 80 },

				-- UTF-8字符处理
				utf8 = { p = 70 },

				-- Treesitter集成：在字符串和注释中禁用自动配对
				tsnode = {
					p = 60,
					separate = {
						"comment",
						"string",
						"char",
						"character",
						"raw_string",
						"string_literal",
					},
				},

				-- 飞行模式：快速跳过闭合符号
				fly = {
					p = 10,
					other_char = { " " }, -- 除了配对外，还可以跳过的字符
					only_jump_end_pair = false,
				},
			},

			-- 退格键配置
			bs = {
				enable = true,
				overjumps = true, -- 允许跳过配对的符号
				space = true, -- 智能处理空格
				indent_ignore = false, -- 不忽略缩进
				delete_from_end = true, -- 从空配对符末尾删除时直接删除整个配对
			},

			-- 回车键配置
			cr = {
				enable = true,
				autoclose = false, -- 自动闭合未完成的配对
				conf = {
					cond = function(fn)
						return not fn.in_lisp() -- 在Lisp类语言中禁用特定行为
					end,
				},
			},

			-- 空格键配置
			space = {
				enable = true,
				check_box_ft = { "markdown", "vimwiki", "org" }, -- 在这些文件类型中支持复选框
			},

			-- 快速跳跃配置（向前）
			fastwarp = {
				enable = true,
				map = "<A-e>", -- Alt+e 向前跳跃
				cmap = "<A-e>",
				multiline = true, -- 支持跨行跳跃
				nocursormove = true, -- 跳跃时不移动光标位置
				faster = true, -- 启用增强跳跃模式
			},

			-- 快速跳跃配置（向后）
			fastwarp_reverse = {
				enable = true,
				rmap = "<A-E>", -- Alt+Shift+e 向后跳跃
				rcmap = "<A-E>",
			},

			-- 自动闭合配置
			close = {
				enable = true,
				map = "<A-)>>", -- Alt+) 自动闭合所有开口的配对
				do_nothing_if_fail = true, -- 如果失败不插入字符
			},

			-- 跳出配对配置
			tabout = {
				enable = true, -- 默认禁用，按需开启
				map = "<C-l>", -- Alt+tab 跳出当前配对
				hopout = true, -- 从空配对中跳出
			},
		})
	end,
}
