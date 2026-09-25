-- https://github.com/stevearc/conform.nvim

return {
	"stevearc/conform.nvim",
	event = "BufReadPost",
	keys = {
		{
			"<leader>of",
			function()
				require("conform").format({ async = true })
			end,
			mode = "",
			desc = "conform: Format buffer",
		},
	},
	config = function()
		local slow_format_filetypes = {}
		require("conform").setup({
			-- Define your formatters
			formatters_by_ft = {
				lua = { "stylua" },
				toml = { "taplo" },
				-- https://github.com/jqlang/jq
				json = { "jq" },
				c = { "clang-format" },
				html = { "dprint" },
				-- c={ "astyle" },
				rust = { "rustfmt" },
				javascript = { "biome" },
				python = { "ruff_format" },
				sh = { "shfmt" },
				go = { "gofumpt" },
				markdown = { "codefmt" },
			},
			-- Set up format-on-save
			format_on_save = function(bufnr)
				if slow_format_filetypes[vim.bo[bufnr].filetype] then
					return
				end
				local function on_format(err)
					if err and err:match("timeout$") then
						slow_format_filetypes[vim.bo[bufnr].filetype] = true
					end
				end

				return { timeout_ms = 200, lsp_fallback = true }, on_format
			end,

			format_after_save = function(bufnr)
				if not slow_format_filetypes[vim.bo[bufnr].filetype] then
					return
				end
				return {
					lsp_fallback = true,
				}
			end,
			-- Customize formatters
			formatters = {
				shfmt = { prepend_args = { "-i", "2" } },
				codefmt = {
					command = "codefmt",
				},
			},
		})

		-- Customize the "injected" formatter
		require("conform").formatters.injected = {
			-- Set the options field
			options = {
				-- Set to true to ignore errors
				ignore_errors = false,
				-- Map of treesitter language to file extension
				-- A temporary file name with this extension will be generated during formatting
				-- because some formatters care about the filename.
				lang_to_ext = {
					bash = "sh",
					c_sharp = "cs",
					elixir = "exs",
					javascript = "js",
					julia = "jl",
					latex = "tex",
					markdown = "md",
					python = "py",
					ruby = "rb",
					rust = "rs",
					teal = "tl",
					r = "r",
					typescript = "ts",
				},
				-- Map of treesitter language to formatters to use
				-- (defaults to the value from formatters_by_ft)
				lang_to_formatters = {},
			},
		}

		-- 格式化设置
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
