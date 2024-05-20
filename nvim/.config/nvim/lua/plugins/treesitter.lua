-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
		"nvim-treesitter/nvim-treesitter-textobjects",
		"nvim-treesitter/nvim-treesitter-context",
	},
	config = function()
		-- 导入 Treesitter 插件的配置模块(语法分析器)
		local configs = require("nvim-treesitter.configs")
		-- 设置 Treesitter 插件的配置
		configs.setup({
			-- 确保所需的语言解析器被安装
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"markdown",
				"markdown_inline",
				"regex",
				"bash",
				"c",
				"cmake",
				"json",
			},
			-- 是否同步安装解析器
			sync_install = true,
			-- 是否自动安装解析器
			auto_install = true,
			-- 忽略安装的解析器模块
			-- ignore_install = { "text" },
			-- 启用缩进模块
			indent = {
				enable = true,
			},
			-- 高亮模块配置
			highlight = {
				enable = true,
				-- 或者使用一个函数来灵活配置，例如，对于大文件禁用 Treesitter 高亮以提高性能
				disable = function(lang, buf)
					local max_filesize = 1 * 1024 * 1024 -- 1 MB
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						return true
					end
				end,
				-- 关闭 vim 自带语法高亮引擎，只使用 Treesitter
				additional_vim_regex_highlighting = false,
			},
			-- 启用增量选择模块
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<CR>",
					node_incremental = "<CR>",
					node_decremental = "<BS>",
					scope_incremental = "<TAB>",
				},
			},
			-- 设置文本对象选择操作
			textobjects = {
				-- 启用与LSP交互的文本对象
				lsp_interop = {
					enable = true,
					border = "none", -- 边框样式设置为无边框
					floating_preview_opts = {}, -- 悬浮预览选项，用于配置悬浮窗口的外观和行为
					-- 使用快捷键来预览函数和类的定义
					peek_definition_code = {
						["<leader>k"] = { query = "@function.outer", desc = "预览函数的外部区域定义" }, -- 查看函数的外部区域定义
						["<leader>K"] = { query = "@class.outer", desc = "预览类的外部区域定义" }, -- 查看类的外部区域定义
					},
				},
				select = {
					enable = true,
					-- 自动跳转到文本对象，类似于 targets.vim 插件
					lookahead = true,
					keymaps = {
						-- 使用 textobjects.scm 中定义的捕获组进行选择
						["af"] = {
							query = "@function.outer",
							desc = "选择函数的外部区域",
						},
						["if"] = {
							query = "@function.inner",
							desc = "选择函数的内部区域",
						},
						["ac"] = { query = "@class.outer", desc = "选择类的外部区域" }, -- 选择类的外部区域
						["ic"] = { query = "@class.inner", desc = "选择类的内部区域" }, -- 选择类的内部区域
						["as"] = { query = "@scope", desc = "选择语言范围", query_group = "locals" }, -- 选择语言范围
					},
					-- 选择模式设置
					selection_modes = {
						["@parameter.outer"] = "v", -- 字符模式
						["@function.outer"] = "V", -- 行模式
						["@class.outer"] = "<c-v>", -- 块模式
					},
					-- 控制是否包含周围的空白字符
					include_surrounding_whitespace = true,
				},
			},
		})
	end,
}
