-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = "VeryLazy",
	config = function()
		require("nvim-treesitter.configs").setup({
			-- windwp/nvim-ts-autotag
			autotag = {
				enable = true,
			},
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"markdown",
				"markdown_inline",
				"regex",
				"bash",
				"html",
				"json5",
			},
			-- 同步安装解析器
			sync_install = true,
			-- 自动安装解析器
			auto_install = true,
			-- 缩进模块
			indent = {
				enable = true,
			},
			-- 高亮模块配置
			highlight = {
				enable = true,
				-- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
				disable = function(lang, buf)
					local max_filesize = 100 * 1024 -- 100 KB
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						return true
					end
				end,
				-- 关闭vim自带语法高亮引擎，只使用treesitter.
				-- 设置为true，可能会降低neovim速度。
				additional_vim_regex_highlighting = false,
			},
			-- 增量选择模块
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<CR>",
					node_incremental = "<CR>",
					node_decremental = "<BS>",
					scope_incremental = "<TAB>",
				},
			},
		})
	end,
}
