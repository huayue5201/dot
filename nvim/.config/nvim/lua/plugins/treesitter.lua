-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = { "BufReadPre", "BufNewFile" },
	-- https://github.com/LiadOz/nvim-dap-repl-highlights
	dependencies = "LiadOz/nvim-dap-repl-highlights",
	config = function()
		require("nvim-dap-repl-highlights").setup()
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
				"dap_repl",
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
		})
	end,
}
