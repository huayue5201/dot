-- https://github.com/stevearc/conform.nvim

return {
	"stevearc/conform.nvim",
	event = "BufReadPost",
	config = function()
		local slow_format_filetypes = {}
		require("conform").setup({
			formatters = {
				bake = function(bufnr)
					-- 根据缓冲区或文件类型动态设置 bake 配置
					local filetype = vim.bo[bufnr].filetype
					if filetype == "make" then
						return {
							command = "bake format Makefile",
						}
					else
						return {
							command = "bake",
						}
					end
				end,
			},

			formatters_by_ft = {
				lua = { "stylua" },
				toml = { "taplo" },
				-- https://github.com/jqlang/jq
				json = { "jq" },
				c = { "clang-format" },
				-- c={ "astyle" },
				rust = { "rustfmt" },
				-- https://github.com/EbodShojaei/bake
				-- TODO:没有配置成功
				make = { "bake" },
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
		})

		-- 格式化设置
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

		vim.keymap.set("v", "<s-a-F>", function()
			require("conform").format({ range = true })
		end, { desc = "Format selected code" })

		vim.keymap.set("n", "<s-a-F>", function()
			require("conform").format({ async = true })
		end, { desc = "Format buffer" })
	end,
}
