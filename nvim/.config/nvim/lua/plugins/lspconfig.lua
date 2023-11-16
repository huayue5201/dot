-- https://github.com/neovim/nvim-lspconfig

-- lsp source列表
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"j-hui/fidget.nvim",
	},
	config = function()
		-- nvim-cmp
		local cmp_capabilities = require("cmp_nvim_lsp").default_capabilities()

		local lspconfig = require("lspconfig")

		local language_servers = require("lspconfig").util.available_servers()
		for _, lsp in ipairs(language_servers) do
			lspconfig[lsp].setup({
				capabilities = { cmp_capabilities },
			})
		end

		-- 加载lsp配置文件 lua/lsp/...
		require("lsp-sever.lua_ls")
		require("lspconfig").rust_analyzer.setup({})
		-- https://github.com/mtshiba/pylyzer
		require("lspconfig").pylyzer.setup({})
		-- toml-sever
		-- https://github.com/tamasfe/taplo
		require("lspconfig").taplo.setup({})
		-- https://github.com/typescript-language-server/typescript-language-server
		require("lspconfig").tsserver.setup({})
		-- html-sever
		-- https://github.com/olrtg/emmet-language-server
		require("lspconfig").emmet_language_server.setup({})

		-- 诊断图标
		local signs = { Error = "⊗", Warn = "", Hint = "󰌶", Info = "󰙎" }
		for type, icon in pairs(signs) do
			local hl = "DiagnosticSign" .. type
			vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
		end

		-- 显示诊断来源
		vim.diagnostic.config({
			virtual_text = {
				source = "if_many", -- Or "if_many"
				prefix = "▪",
			},
			float = {
				source = "if_many", -- Or "if_many"
			},
		})

		-- 查看当前buffer内错误
		vim.keymap.set(
			"n",
			"<leader>wx",
			"<cmd>lua require('telescope.builtin').diagnostics()<cr>",
			{ desc = "查看错误" }
		)
		-- vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist)
		-- 跳转到下一个错误
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "跳转到下一个错误" })
		-- 跳转到上一个错误
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "跳转到上一个错误" })
		-- 浮窗查看错误信息
		vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, { desc = "浮窗查看错误信息" })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf }

				-- 跳转到定义
				vim.keymap.set(
					"n",
					"gd",
					"<cmd>lua require('telescope.builtin').lsp_definitions()<cr>",
					{ desc = "跳转到定义" },
					opts
				)
				-- vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "跳转到定义" }, opts)
				-- 跳转到类型定义
				vim.keymap.set(
					"n",
					"gD",
					"<cmd>lua require('telescope.builtin').lsp_type_definitions()<cr>",
					{ desc = "跳转到类型定义" },
					opts
				)
				-- vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { desc = "跳转到类型定义" }, opts)
				-- 查看实现
				vim.keymap.set(
					"n",
					"gi",
					"<cmd>lua require('telescope.builtin').lsp_implementations()<cr>",
					{ desc = "查看实现" },
					opts
				)
				-- vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "查看实现" }, opts)
				-- 查看引用
				vim.keymap.set(
					"n",
					"gr",
					"<cmd>lua require('telescope.builtin').lsp_references()<cr>",
					{ desc = "查看引用" },
					opts
				)
				-- vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "查看lsp引用" }, opts)
				-- 跳转到声明
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "跳转到声明" }, opts)
				-- 查看文档
				vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "查看文档" }, opts)
				-- 查看签名帮助
				vim.keymap.set({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, { desc = "签名帮助" }, opts)
				-- 代码操作
				vim.keymap.set({ "n", "x" }, "<space>ca", vim.lsp.buf.code_action, { desc = "代码操作" }, opts)
				-- 重命名
				vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, { desc = "重命名" }, opts)
				-- 添加workspace
				vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "添加workspace" }, opts)
				-- 重命名workspace
				vim.keymap.set(
					"n",
					"<space>wn",
					vim.lsp.buf.remove_workspace_folder,
					{ desc = "重命名workspace" },
					opts
				)
				-- 查看workspace
				vim.keymap.set("n", "<space>wl", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, { desc = "查看workspace" }, opts)
				-- 格式化当前buffer
				-- vim.keymap.set("n", "<leader>wf", function()
				-- 	vim.lsp.buf.format({ async = true })
				-- end, { desc = "代码格式化" }, opts)
			end,
		})
	end,
}
