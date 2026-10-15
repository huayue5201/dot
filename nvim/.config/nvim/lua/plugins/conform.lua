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
		-- sql 预置为「慢 formatter」：sqlfluff 是 Python CLI，启动+解析通常 >200ms，
		-- 直接走 format_after_save 异步，避免首次保存被 200ms 超时打断。
		local slow_format_filetypes = { sql = true }
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
				markdown = { "injected" },
				-- markdown = { "prettier" }, -- 若装了 prettier，可改为整体格式化 markdown（含表格/列表换行）
				-- https://github.com/sqlfluff/sqlfluff
				sql = { "sqlfluff" },
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
				-- conform 内置 sqlfluff formatter 是 `sqlfluff fix -`，且 require_cwd = true：
				-- 项目里没有 .sqlfluff/pyproject.toml/setup.cfg/tox.ini/pep8.ini 时会被跳过。
				-- 这里 ① 关掉 require_cwd；② 改用 `format`（只应用排版规则，比 `fix`
				-- 更适合当 formatter，不会顺手改语义类 lint）。
				-- 方言不写死：内置 cwd 会定位到最近的 .sqlfluff 所在目录，找不到就用
				-- ~/.config/sqlfluff/.sqlfluff 里的全局默认。
				sqlfluff = {
					require_cwd = false,
					args = { "format", "-" },
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
