-- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
-- https://github.com/neovim/neovim/issues/39006
-- 需要安装: brew install tree-sitter-cli

return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		"LiadOz/nvim-dap-repl-highlights",
	},
	config = function()
		require("nvim-dap-repl-highlights").setup()

		local ensure_installed = {
			"c",
			"lua",
			"vim",
			"vimdoc",
			"python",
			"javascript",
			"typescript",
			"bash",
			"html",
			"css",
			-- "json",
			"markdown",
			"markdown_inline",
			"dap_repl",
			"go",
			"rust",
			"regex",
			"comment",
			"query",
		}

		-- 安装解析器
		require("nvim-treesitter").install(ensure_installed)

		-- 启用高亮、折叠、缩进等功能
		vim.api.nvim_create_autocmd("FileType", {
			pattern = ensure_installed,
			callback = function(args)
				local buf = args.buf
				local winid = vim.api.nvim_get_current_win()
				vim.treesitter.start(buf)
				vim.wo[winid].foldexpr = "v:lua.vim.treesitter.foldexpr()"
				vim.wo[winid].foldmethod = "expr"
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
