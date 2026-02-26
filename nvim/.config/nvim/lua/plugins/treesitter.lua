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
			"regex",
			"comment", -- 用于注释高亮
		}

		require("nvim-treesitter").install(ensure_installed)

		-- 添加重装指定语法文件的命令（只重装 ensure_installed 中的语言）
		vim.api.nvim_create_user_command("TSReinstall", function()
			local total = #ensure_installed
			for i, lang in ipairs(ensure_installed) do
				vim.cmd("TSInstall! " .. lang)
				print(string.format("[%d/%d] Reinstalled %s parser", i, total, lang))
			end
			print("All configured treesitter parsers reinstalled")
		end, {
			desc = "Reinstall all treesitter parsers from ensure_installed list",
		})

		-- 添加重装单个语法文件的命令（方便调试）
		vim.api.nvim_create_user_command("TSReinstallLang", function(opts)
			local lang = opts.args
			vim.cmd("TSInstall! " .. lang)
			print("Reinstalled " .. lang .. " parser")
		end, {
			nargs = 1,
			desc = "Reinstall a specific treesitter parser",
		})

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
