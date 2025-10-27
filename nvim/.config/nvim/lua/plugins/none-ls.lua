-- https://github.com/nvimtools/none-ls.nvim

return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	event = { "BufReadPre", "BufNewFile" },
	keys = {
		{
			"<localleader>f",
			function()
				vim.lsp.buf.format({ async = true })
			end,
			mode = "n",
			desc = "Format buffer",
		},
	},
	config = function()
		local null_ls = require("null-ls")

		null_ls.register({
			name = "ruff_format",
			method = null_ls.methods.FORMATTING,
			filetypes = { "python" },
			generator = null_ls.formatter({
				command = "ruff",
				args = { "format", "--stdin-filename", "$FILENAME", "-" },
				to_stdin = true,
			}),
		})
		null_ls.setup({
			sources = {
				-- lua
				null_ls.builtins.formatting.stylua,
				-- js
				null_ls.builtins.formatting.biome,
				-- sh
				null_ls.builtins.formatting.shfmt.with({
					extra_args = { "-i", "2" },
				}),
			},
		})

		-- 自动保存格式化
		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = "*",
			callback = function()
				vim.lsp.buf.format({ async = false, timeout_ms = 500 })
			end,
		})
	end,
}
