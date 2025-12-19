-- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
-- TODO:需要安装 brew install tree-sitter-cli

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	dependencies = {
		-- https://github.com/LiadOz/nvim-dap-repl-highlights
		"LiadOz/nvim-dap-repl-highlights",
	},
	config = function()
		require("nvim-dap-repl-highlights").setup()
		-- 1. 确保安装需要的语言解析器
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
			"json",
			"markdown",
			"markdown_inline",
			"dap_repl",
			"go",
			"rust",
			"python",
			"regex",
			"rust",
		}

		require("nvim-treesitter").install(ensure_installed)

		vim.api.nvim_create_autocmd("FileType", {
			pattern = ensure_installed,
			callback = function(arg)
				-- 启用语法高亮
				vim.treesitter.start(arg.buf)

				-- 启用基于 Treesitter 的代码折叠
				vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
				vim.wo.foldmethod = "expr"

				-- 启用 Treesitter 缩进
				vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
