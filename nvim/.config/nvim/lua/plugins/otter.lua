-- https://github.com/jmbuhr/otter.nvim

return {
	"jmbuhr/otter.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	opts = {
		-- ==================== LSP 相关配置 ====================
		lsp = {
			-- 诊断信息更新触发事件
			-- 默认只在保存时更新，性能较好
			-- 如需更实时更新可改为 { "BufWritePost", "InsertLeave", "TextChanged" }
			diagnostic_update_events = { "BufWritePost" },

			-- 项目根目录查找规则
			-- 用于确定从哪里启动 otter-ls
			root_dir = function(_, bufnr)
				return vim.fs.root(bufnr or 0, {
					".git", -- Git 仓库根目录
					"_quarto.yml", -- Quarto 项目配置
					"package.json", -- Node.js 项目
					"pyproject.toml", -- Python 项目（可选添加）
					"Cargo.toml", -- Rust 项目（可选添加）
				}) or vim.fn.getcwd(0)
			end,
		},

		-- ==================== Otter 缓冲区配置 ====================
		buffers = {
			-- 是否设置 otter 缓冲区的 filetype
			-- 已废弃，未来版本将默认为 true
			set_filetype = true,

			-- 是否将 otter 缓冲区写入磁盘
			-- 某些 Linter 需要真实文件才能工作时可启用
			-- 文件会在关闭时自动删除
			write_to_disk = false,

			-- 每个语言的代码前缀（插入在代码块之前）
			preambles = {
				-- 示例：为 Python 自动导入常用库
				-- python = { "import numpy as np", "import pandas as pd" },
			},

			-- 每个语言的代码后缀（追加在代码块之后）
			postambles = {},

			-- 忽略特定模式的行（不传递给 otter 缓冲区）
			-- 使用 Lua 模式匹配语法
			ignore_pattern = {
				-- Python: 忽略 IPython 魔法命令（% 开头）和 shell 命令（! 开头）
				python = "^(%s*[%%!].*)",
				-- R: 忽略 R 的注释和帮助命令
				-- r = "^%s*#.*",
			},
		},

		-- ==================== 代码块处理配置 ====================
		-- 需要去除的包裹引号字符（如 markdown 中的 `code`）
		strip_wrapping_quote_characters = { "'", '"', "`" },

		-- 是否处理代码块前的缩进（如 Org 模式中的缩进代码块）
		-- 启用后会有轻微的性​​能开销
		handle_leading_whitespace = true,

		-- ==================== 扩展配置 ====================
		-- 自定义文件类型到扩展名的映射
		extensions = {
			-- ["bash"] = "sh",
			-- ["julia"] = "jl",
		},

		-- ==================== 调试配置 ====================
		debug = false, -- 启用 LSP 事件调试日志
		verbose = {
			no_code_found = false, -- 当没有找到代码时是否警告
		},
	},
}
