-- https://github.com/nvim-treesitter/nvim-treesitter

vim.g.now(function()
	vim.g.add({
		source = "nvim-treesitter/nvim-treesitter",
		-- Use 'master' while monitoring updates in 'main'
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
		depnds = { "nvim-treesitter/nvim-treesitter-textobjects" },
		checkout = "master",
		monitor = "main",
		-- Perform action after every checkout
		hooks = {
			post_checkout = function()
				vim.cmd("TSUpdate")
			end,
		},
	})

	require("nvim-treesitter.configs").setup({
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
			"rust",
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
				init_selection = "<leader>v",
				node_incremental = "<leader>v",
				node_decremental = "<BS>",
				scope_incremental = "<TAB>",
			},
		},
		-- 设置文本对象选择操作
		textobjects = {
			-- 启用与LSP交互的文本对象
			-- lsp_interop = {
			-- 	enable = true,
			-- 	border = "none", -- 边框样式设置为无边框
			-- 	floating_preview_opts = {}, -- 悬浮预览选项，用于配置悬浮窗口的外观和行为
			-- 	-- 使用快捷键来预览函数和类的定义
			-- 	peek_definition_code = {
			-- 		["<leader>k"] = { query = "@function.outer", desc = "预览函数的外部区域定义" }, -- 查看函数的外部区域定义
			-- 		["<leader>K"] = { query = "@class.outer", desc = "预览类的外部区域定义" }, -- 查看类的外部区域定义
			-- 	},
			-- },
			move = {
				enable = true,
				set_jumps = true, -- whether to set jumps in the jumplist
				goto_next_start = {
					["]m"] = "@function.outer",
					["gj"] = "@function.outer",
					["]]"] = "@class.outer",
					["]b"] = "@block.outer",
					["]a"] = "@parameter.inner",
				},
				goto_next_end = {
					["]M"] = "@function.outer",
					["gJ"] = "@function.outer",
					["]["] = "@class.outer",
					["]B"] = "@block.outer",
					["]A"] = "@parameter.inner",
				},
				goto_previous_start = {
					["[m"] = "@function.outer",
					["gk"] = "@function.outer",
					["[["] = "@class.outer",
					["[b"] = "@block.outer",
					["[a"] = "@parameter.inner",
				},
				goto_previous_end = {
					["[M"] = "@function.outer",
					["gK"] = "@function.outer",
					["[]"] = "@class.outer",
					["[B"] = "@block.outer",
					["[A"] = "@parameter.inner",
				},
			},
			select = {
				enable = true,
				-- 自动跳转到文本对象，类似于 targets.vim 插件
				lookahead = true,
				keymaps = {
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["ac"] = "@class.outer",
					["ic"] = "@class.inner",
					["ab"] = "@block.outer",
					["ib"] = "@block.inner",
					["al"] = "@loop.outer",
					["il"] = "@loop.inner",
					["a/"] = "@comment.outer",
					["i/"] = "@comment.outer", -- no inner for comment
					["aa"] = "@parameter.outer", -- parameter -> argument
					["ia"] = "@parameter.inner",
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
end)
