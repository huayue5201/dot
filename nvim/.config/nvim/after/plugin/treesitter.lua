-- https://github.com/nvim-treesitter/nvim-treesitter

vim.g.now(function()
	vim.g.add({
		source = "nvim-treesitter/nvim-treesitter",
		checkout = "master",
		monitor = "main",
		hooks = {
			post_checkout = function()
				vim.cmd("TSUpdate")
			end,
		},
	})

	vim.g.add({
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
		source = "nvim-treesitter/nvim-treesitter-textobjects",
		depends = { "nvim-treesitter/nvim-treesitter" },
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
			disable = function(_, buf)
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
				init_selection = "<cr>",
				node_incremental = "<cr>",
				node_decremental = "<BS>",
				scope_incremental = "<TAB>",
			},
		},
		-- 设置文本对象选择操作
		textobjects = {
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
