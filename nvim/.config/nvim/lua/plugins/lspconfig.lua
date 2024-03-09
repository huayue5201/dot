-- https://github.com/neovim/nvim-lspconfig

-- lsp source列表
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"williamboman/mason.nvim",
		"j-hui/fidget.nvim",
	},
	config = function()
		-- 获取 nvim-cmp 插件提供的 LSP 客户端能力
		local cmp_capabilities = require("cmp_nvim_lsp").default_capabilities()
		-- 引入 lspconfig 模块
		local lspconfig = require("lspconfig")
		-- 获取可用的语言服务器列表
		local language_servers = lspconfig.util.available_servers()
		-- 创建一个表用于存储共享的语言服务器配置
		local shared_server_config = {
			capabilities = { cmp_capabilities },
		}
		-- 为每个语言服务器设置配置
		for _, lsp in ipairs(language_servers) do
			-- 检查语言服务器是否存在于 lspconfig 中
			if lspconfig[lsp] then
				-- 设置语言服务器配置
				lspconfig[lsp].setup(shared_server_config)
			end
		end

		-- 加载 Lua LSP 配置
		require("lsp-server.lua_ls").setupLuaLs()
		-- 加载 Clangd 配置
		require("lsp-server.clangd").setupClangd()
		-- 加载 Taplo LSP 配置
		require("lspconfig").taplo.setup({})
		-- 加载 ASM LSP 配置
		require("lspconfig").asm_lsp.setup({})

		-- 显示诊断来源
		vim.diagnostic.config({
			virtual_text = {
				source = "if_many", -- Or "if_many"
				prefix = "▪",
			},
			float = {
				source = "if_many", -- Or "if_many"
			},
			signs = {
				-- 诊断图标
				text = {
					[vim.diagnostic.severity.ERROR] = "", -- or other icon of your choice here, this is just what my config has:
					[vim.diagnostic.severity.WARN] = "",
					[vim.diagnostic.severity.INFO] = "",
					[vim.diagnostic.severity.HINT] = "󰌵",
				},
			},
		})

		-- 查看当前buffer内错误
		vim.keymap.set("n", "<space>ld", vim.diagnostic.setloclist, { desc = "查看代码错误" })
		-- 跳转到下一个错误
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "跳转到下一个错误" })
		-- 跳转到上一个错误
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "跳转到上一个错误" })
		-- 浮窗查看错误信息
		vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, { desc = "浮窗查看错误信息" })

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				-- inlay_hint
				-- local client = vim.lsp.get_client_by_id(ev.data.client_id)
				-- if client.server_capabilities.inlayHintProvider then
				-- 	vim.lsp.inlay_hint.enable(ev.buf, true)
				-- end

				-- Enable completion triggered by <c-x><c-o>
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"

				-- Buffer local mappings.
				-- See `:help vim.lsp.*` for documentation on any of the below functions
				local opts = { buffer = ev.buf }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "跳转到定义" }, opts)
				vim.keymap.set("n", "ge", vim.lsp.buf.type_definition, { desc = "跳转到类型定义" }, opts)
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "查看实现" }, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "查看lsp引用" }, opts)
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "跳转到声明" }, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "查看文档" }, opts)
				vim.keymap.set({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, { desc = "签名帮助" }, opts)
				vim.keymap.set({ "n", "x" }, "<space>ca", vim.lsp.buf.code_action, { desc = "代码操作" }, opts)
				vim.keymap.set({ "n", "v" }, "<space>rn", vim.lsp.buf.rename, { desc = "重命名" }, opts)
				vim.keymap.set("n", "<space>aw", vim.lsp.buf.add_workspace_folder, { desc = "添加workspace" }, opts)
				vim.keymap.set(
					"n",
					"<space>rw",
					vim.lsp.buf.remove_workspace_folder,
					{ desc = "重命名workspace" },
					opts
				)
				vim.keymap.set("n", "<space>lw", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, { desc = "查看workspace" }, opts)
				-- vim.keymap.set("n", "<S-A-f>", function()
				-- 	vim.lsp.buf.format({ async = true })
				-- end, { desc = "代码格式化" }, opts)
			end,
		})
	end,
}
