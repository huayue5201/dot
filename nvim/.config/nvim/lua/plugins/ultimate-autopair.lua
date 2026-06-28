-- ultimate-autopair.nvim 完整配置
-- 插件地址: https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	-- 延迟加载：只在需要时加载
	event = { "InsertEnter", "CmdlineEnter" },
	config = function()
		require("ultimate-autopair").setup({
			-- ========== 基础开关 ==========
			map = true, -- 插入模式启用映射
			cmap = true, -- 命令行模式启用映射
			pair_map = true, -- 启用配对的映射（如输入 '(' 自动补 ')'）
			pair_cmap = true, -- 命令行中启用配对的映射
			multiline = true, -- 支持多行配对（跨行处理，最多1000行）

			-- ========== 内置配对规则 ==========
			internal_pairs = {
				-- 方括号：支持飞行模式、包围、回车展开、空格展开
				{ "[", "]", fly = true, dosuround = true, newline = true, space = true },
				-- 圆括号：同上
				{ "(", ")", fly = true, dosuround = true, newline = true, space = true },
				-- 花括号：同上
				{ "{", "}", fly = true, dosuround = true, newline = true, space = true },

				-- 尖括号（HTML/JSX/TSX 用户取消注释）
				{
					"<",
					">",
					fly = true,
					dosuround = true,
					newline = true,
					space = true,
					ft = { "html", "vue", "jsx", "tsx", "xml" },
				},

				-- 双引号：支持包围，不支持多行（避免字符串内误配对）
				{ '"', '"', suround = true, multiline = false },
				-- 单引号：支持包围，不在 LaTeX 中启用（避免与撇号冲突）
				{ "'", "'", suround = true, multiline = false, nft = { "tex" } },
				-- 反引号：支持包围
				{ "`", "`", suround = true, multiline = false },

				-- ========== 语言特定配对 ==========
				-- HTML/XML/Markdown 注释
				{ "<!--", "-->", ft = { "markdown", "html", "xml" }, space = true },
				-- Markdown 代码块（回车时自动换行）
				{ "```", "```", newline = true, ft = { "markdown" } },
				-- Python 三引号多行字符串
				{ '"""', '"""', newline = true, ft = { "python" } },
				{ "'''", "'''", newline = true, ft = { "python" } },
				-- LaTeX 数学模式
				{ "$$", "$$", ft = { "tex", "latex" } },
				-- Rust 原始字符串
				{ 'r#"', '"#', ft = { "rust" } },
			},

			-- ========== 配置内部配对的默认行为 ==========
			config_internal_pairs = {
				-- 示例：修改默认括号的行为
				-- { "(", ")", suround = false, fly = false },
			},

			-- ========== 退格键配置 ==========
			bs = {
				enable = true, -- 启用退格键增强
				map = "<bs>", -- 退格键映射
				cmap = "<bs>", -- 命令行退格键映射
				overjumps = true, -- 允许跳过配对的符号（删除括号时智能处理）
				space = true, -- 智能处理空格（删除 ( ) 中间的空格）
				indent_ignore = false, -- 不忽略缩进（false: 保留缩进）
				single_delete = false, -- 单次删除整个结构（如 <!--|--> 删除整个注释）
				delete_from_end = true, -- 从空配对的末尾删除时直接删除整个配对
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
			},

			-- ========== 回车键配置 ==========
			cr = {
				enable = true, -- 启用回车键增强
				map = "<cr>", -- 回车键映射
				autoclose = true, -- 自动闭合未完成的配对（如 { 回车后自动补 }）
				multi = false, -- 是否使用多个配置
				conf = {
					-- 在 Lisp 类语言中禁用某些行为（Lisp 括号语法特殊）
					cond = function(fn)
						return not fn.in_lisp()
					end,
				},
			},

			-- ========== 空格键配置 ==========
			space = {
				enable = true, -- 启用空格键增强
				map = " ", -- 空格键映射
				cmap = " ", -- 命令行空格键映射
				check_box_ft = { "markdown", "vimwiki", "org" }, -- 支持复选框自动补全
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
				-- 内部使用，可能被移除
				-- _check_box_ft2 = { "norg" },
			},

			-- ========== 空格平衡配置 ==========
			space2 = {
				enable = true, -- 启用空格平衡
				match = [[\k]], -- 匹配单词字符（字母、数字、下划线）
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
				-- 效果：在 ( foo * ) 输入字符时自动平衡空格 → ( foo c* )
			},

			-- ========== 快速跳跃（向前） ==========
			fastwarp = {
				enable = true, -- 启用快速跳跃
				enable_normal = true, -- 启用普通模式
				enable_reverse = true, -- 启用反向跳跃
				hopout = false, -- 是否跳出配对
				map = "<A-e>", -- Alt+e 向前跳到下一个闭合符
				rmap = "<A-E>", -- Alt+Shift+e 向后跳到上一个闭合符
				cmap = "<A-e>", -- 命令行中也生效
				rcmap = "<A-E>", -- 命令行反向
				multiline = true, -- 支持跨行跳跃
				nocursormove = true, -- 跳跃时不移动光标位置
				do_nothing_if_fail = true, -- 如果失败则不输入任何字符
				faster = true, -- 增强跳跃模式（更快）
				no_filter_nodes = { -- 跳过过滤的 Treesitter 节点
					"string",
					"raw_string",
					"string_literals",
					"character_literal",
				},
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
			},

			-- ========== 自动闭合配置 ==========
			close = {
				enable = true, -- 启用自动闭合
				map = "<A-)>", -- Alt+) 自动闭合所有开口的配对
				cmap = "<A-)>", -- 命令行中也生效
				do_nothing_if_fail = true, -- 如果失败则不输入任何字符
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
			},

			-- ========== 跳出配对配置 ==========
			tabout = {
				enable = true, -- 启用跳出配对
				map = "<C-l>", -- Ctrl+l 跳出当前配对
				cmap = "<C-l>", -- 命令行中也生效
				hopout = true, -- 从空配对中也能跳出
				do_nothing_if_fail = true, -- 如果不在配对内则正常输入
				multi = false, -- 是否使用多个配置
				conf = {}, -- 扩展配置
			},

			-- ========== 扩展功能配置 ==========
			extensions = {
				-- 大文件保护
				bigfile = {
					p = 110, -- 优先级
					row_limit = 2000, -- 超过2000行时自动禁用
					byte_limit = 5 * 1024 * 1024, -- 超过5MB时自动禁用
				},

				-- 命令行类型过滤
				cmdtype = {
					p = 100,
					skip = { "/", "?", "@", "-" }, -- 跳过的命令行类型
				},

				-- 文件类型过滤
				filetype = {
					p = 90,
					nft = { "TelescopePrompt" }, -- 在这些文件类型中禁用
					tree = true, -- 使用 Treesitter 检测注入语言
				},

				-- 转义字符检测：跳过已转义的配对（如 \' 中的引号）
				escape = {
					filter = true, -- 启用过滤
					p = 80,
				},

				-- UTF-8 字符转换：将全角括号等转成 ASCII
				utf8 = {
					p = 70,
					-- map = { ["（"] = "(", ["）"] = ")" },  -- 可选：自定义映射
				},

				-- Treesitter 节点过滤：在注释和字符串中禁用自动配对
				tsnode = {
					p = 60,
					separate = {
						"comment", -- 注释
						"string", -- 字符串
						"char", -- 字符
						"character", -- 字符（其他语言）
						"raw_string", -- 原始字符串
						"string_literal", -- 字符串字面量
						"char_literal", -- 字符字面量
						"template_string", -- 模板字符串 (JS/TS)
						"regex", -- 正则表达式
						"block_comment", -- 块注释
						"line_comment", -- 行注释
					},
				},

				-- 条件扩展
				cond = {
					p = 40,
					filter = true, -- 启用过滤
				},

				-- Alpha 字符检测（在字母前后禁用配对）
				alpha = {
					p = 30,
					filter = false, -- 是否过滤
					all = false, -- 是否检查所有字符，不仅仅是起始配对
				},

				-- 包围扩展
				suround = {
					p = 20,
				},

				-- 飞行模式：快速跳过闭合符号
				fly = {
					p = 10,
					other_char = { " " }, -- 除了配对外，空格也可以跳过
					nofilter = false, -- 不禁用过滤
					only_jump_end_pair = false, -- 只跳过闭合符号（设为true更快）
					-- undomap = "<C-h>",           -- 撤销映射（可选）
					-- undocmap = "<C-h>",          -- 命令行撤销映射
					-- undomapconf = {},            -- 撤销映射配置
				},
			},

			-- ========== 高级选项 ==========
			-- profile = "default",  -- 使用的配置文件（默认 default）
		})
	end,
}
