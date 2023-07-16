-- https://github.com/neovim/nvim-lspconfig

-- lsp source列表
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason-lspconfig.nvim",
		"jose-elias-alvarez/null-ls.nvim",
	},
	config = function()
		local lspconfig = require("lspconfig")

		-- 开启lsp折叠支持
		local fold_capabilities = vim.lsp.protocol.make_client_capabilities()
		fold_capabilities.textDocument.foldingRange = {
			dynamicRegistration = false,
			lineFoldingOnly = true,
		}

		-- 回调函数
		-- local on_attach = function(client, bufnr) end

		-- nvim-cmp
		-- Set up lspconfig.
		local cmp_capabilities = require("cmp_nvim_lsp").default_capabilities()

		-- Enable some language servers with the additional completion capabilities offered by nvim-cmp
		local servers = { "rust_analyzer", "tsserver", "lua_ls", "taplo" }
		for _, lsp in ipairs(servers) do
			lspconfig[lsp].setup({
				-- on_attach = my_custom_on_attach,
				capabilities = { cmp_capabilities, fold_capabilities },
			})
		end

		-- 加载lsp配置文件 lua/lsp/...
		require("lsp-sever.lua_ls")
		require("lsp-sever.tsserver")
		require("lsp-sever.rust_analyzer")
		require("lsp-sever.taplo")

		-- 诊断图标
		local signs = { Error = "⊗", Warn = "", Hint = "󰌶", Info = "󰙎" }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
		end

		-- 显示诊断来源
		vim.diagnostic.config({
			virtual_text = {
				source = "always", -- Or "if_many"
				prefix = "▪", -- Could be '●', '▎', 'x'
			},
			float = {
				source = "always", -- Or "if_many"
			},
		})

		-- keys

		-- 查看当前buffer内错误
		vim.keymap.set("n", "<space>tb", vim.diagnostic.setloclist, { desc = "查看当前buffer内错误" })
		-- 查看所有错误
		vim.keymap.set("n", "<leader>tw", require("telescope.builtin").diagnostics, { desc = "查看所有错误" })
		-- 跳转到下一个错误
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "跳转到下一个错误" })
		-- 跳转到上一个错误
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "跳转到上一个错误" })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf }

				-- 代码操作
				vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, { desc = "代码操作" }, opts)
				-- 重命名
				vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, { desc = "重命名" }, opts)
				-- 查看引用
				vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, { desc = "查看引用" }, opts)
				-- 跳转到实现
				vim.keymap.set(
					"n",
					"gi",
					require("telescope.builtin").lsp_implementations,
					{ desc = "跳转到实现" },
					opts
				)
				-- 跳转到定义
				vim.keymap.set(
					"n",
					"gd",
					require("telescope.builtin").lsp_definitions,
					{ desc = "跳转到定义" },
					opts
				)
				-- 跳转到类型定义
				vim.keymap.set(
					"n",
					"gt",
					require("telescope.builtin").lsp_type_definitions,
					{ desc = "跳转到类型定义" },
					opts
				)
				-- 查看传入调用
				vim.keymap.set(
					"n",
					"gl",
					require("telescope.builtin").lsp_incoming_calls,
					{ desc = "查看传入调用" },
					opts
				)
				-- 查看传出调用
				vim.keymap.set(
					"n",
					"gL",
					require("telescope.builtin").lsp_outgoing_calls,
					{ desc = "查看传出调用" },
					opts
				)
				-- 查找lsp符号
				vim.keymap.set(
					"n",
					"<leader>fl",
					"<cmd>Telescope lsp_workspace_symbols<cr>",
					{ desc = "查找lsp符号" },
					opts
				)
				-- 查看文档
				vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "查看文档" }, opts)
				-- 添加workspace
				vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "添加workspace" }, opts)
				-- 重命名workspace
				vim.keymap.set(
					"n",
					"<space>wr",
					vim.lsp.buf.remove_workspace_folder,
					{ desc = "重命名workspace" },
					opts
				)
				-- 查看workspace
				vim.keymap.set("n", "<space>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, { desc = "查看workspace" }, opts)
				-- 格式化当前buffer
				vim.keymap.set("n", ";f", function()
					vim.lsp.buf.format({ async = true })
				end, { desc = "代码格式化" }, opts)
			end,
		})
	end,
}
