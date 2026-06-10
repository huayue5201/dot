-- https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	-- 只在需要时加载：进入插入模式或命令行模式时
	event = { "InsertEnter", "CmdlineEnter" },
	config = function()
		require("ultimate-autopair").setup({
			-- ========== 基础开关 ==========
			map = true, -- 插入模式启用映射
			cmap = true, -- 命令行模式启用映射
			pair_map = true, -- 启用配对的映射（如输入 '(' 自动补 ')'）
			pair_cmap = true, -- 命令行中启用配对的映射
			multiline = true, -- 支持多行配对（跨行处理）

			-- ========== 内置配对规则 ==========
			internal_pairs = {
				-- 方括号：支持飞行模式、包围、回车展开、空格展开
				{ "[", "]", fly = true, dosuround = true, newline = true, space = true },
				-- 圆括号：同上
				{ "(", ")", fly = true, dosuround = true, newline = true, space = true },
				-- 花括号：同上
				{ "{", "}", fly = true, dosuround = true, newline = true, space = true },

				-- 尖括号（HTML/JSX 用户取消注释）
				-- { "<", ">", fly = true, dosuround = true, newline = true, space = true,
				--   ft = { "html", "vue", "jsx", "tsx" } },

				-- 双引号：支持包围，不支持多行（避免字符串内误配对）
				{ '"', '"', suround = true, multiline = false },
				-- 单引号：支持包围，不在 LaTeX 中启用（避免与撇号冲突）
				{ "'", "'", suround = true, multiline = false, nft = { "tex" } },
				-- 反引号：支持包围
				{ "`", "`", suround = true, multiline = false },

				-- ========== 语言特定配对 ==========
				-- HTML/XML/Markdown 注释
				{ "<!--", "-->", ft = { "markdown", "html" }, space = true },
				-- Markdown 代码块（回车时自动换行）
				{ "```", "```", newline = true, ft = { "markdown" } },
				-- Python 三引号多行字符串
				{ '"""', '"""', newline = true, ft = { "python" } },
				{ "'''", "'''", newline = true, ft = { "python" } },
			},

			-- ========== 扩展功能配置 ==========
			extensions = {
				-- 大文件保护：超过 2000 行时自动禁用，防止卡顿
				bigfile = {
					p = 110, -- 优先级（越高越早加载）
					row_limit = 2000, -- 行数阈值
					byte_limit = 5 * 1024 * 1024, -- 字节阈值（5MB）
				},

				-- 文件类型过滤：在 Telescope 提示符中禁用
				filetype = {
					p = 90,
					nft = { "TelescopePrompt" }, -- 不禁用的文件类型（排除 Telescope）
					tree = true, -- 使用 Treesitter 检测注入语言
				},

				-- 转义字符检测：跳过已转义的配对（如 \' 中的引号）
				escape = { filter = true, p = 80 },

				-- UTF-8 字符转换：将全角括号等转成 ASCII
				utf8 = { p = 70 },

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
					},
				},

				-- 飞行模式：快速跳过闭合符号（按 ) 时直接跳过已有的 )）
				fly = {
					p = 10,
					other_char = { " " }, -- 除了配对外，空格也可以跳过
					only_jump_end_pair = true, -- 只跳过闭合符号
				},
			},

			-- ========== 退格键配置 ==========
			bs = {
				enable = true, -- 启用退格键增强
				overjumps = true, -- 允许跳过配对的符号（删除括号时智能处理）
				space = true, -- 智能处理空格（删除 ( ) 中间的空格）
				indent_ignore = false, -- 不忽略缩进
				delete_from_end = true, -- 从空配对的末尾删除时直接删除整个配对
			},

			-- ========== 回车键配置 ==========
			cr = {
				enable = true, -- 启用回车键增强
				autoclose = true, -- 自动闭合未完成的配对（如 { 回车后自动补 }）
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
				-- 在这些文件类型中支持复选框自动补全（如 [ ] 变成 [x]）
				check_box_ft = { "markdown", "vimwiki", "org" },
			},

			-- ========== 空格平衡配置（可选） ==========
			space2 = {
				enable = true, -- 启用空格平衡
				match = [[\k]], -- 匹配单词字符（字母、数字、下划线）
				-- 效果：在 ( foo * ) 输入字符时自动平衡空格 → ( foo c* )
			},

			-- ========== 快速跳跃（向前） ==========
			fastwarp = {
				enable = true, -- 启用快速跳跃
				map = "<A-e>", -- Alt+e 向前跳到下一个闭合符
				cmap = "<A-e>", -- 命令行中也生效
				multiline = true, -- 支持跨行跳跃
				nocursormove = true, -- 跳跃时不移动光标位置
				faster = true, -- 增强跳跃模式（更快）
			},

			-- ========== 快速跳跃（向后） ==========
			fastwarp_reverse = {
				enable = true, -- 启用反向快速跳跃
				rmap = "<A-E>", -- Alt+Shift+e 向后跳到上一个闭合符
				rcmap = "<A-E>",
			},

			-- ========== 自动闭合配置 ==========
			close = {
				enable = true, -- 启用自动闭合
				map = "<A-)>", -- Alt+) 自动闭合所有开口的配对
				do_nothing_if_fail = true, -- 如果失败（没有未闭合的括号）则不输入任何字符
			},

			-- ========== 跳出配对配置 ==========
			tabout = {
				enable = true, -- 启用跳出配对
				map = "<C-l>", -- Ctrl+l 跳出当前配对（如从 (|) 跳到 ()|）
				hopout = true, -- 从空配对中也能跳出
				do_nothing_if_fail = true, -- 如果不在配对内则正常输入 l
			},
		})
	end,
}
