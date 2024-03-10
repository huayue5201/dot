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

		-- 配置诊断显示方式
		vim.diagnostic.config({
			virtual_text = {
				source = "if_many", -- 显示虚拟文本
				prefix = "▪", -- 虚拟文本前缀
			},
			float = {
				source = "if_many", -- 显示浮动窗口
			},
			signs = {
				-- 设置诊断图标
				text = {
					[vim.diagnostic.severity.ERROR] = "", -- 错误
					[vim.diagnostic.severity.WARN] = "", -- 警告
					[vim.diagnostic.severity.INFO] = "", -- 信息
					[vim.diagnostic.severity.HINT] = "󰌵", -- 提示
				},
			},
		})

		-- 设置键映射
		vim.keymap.set("n", "<space>qd", vim.diagnostic.setloclist, { desc = "代码错误列表" })
		vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "跳转到前一个错误" })
		vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "跳转到下一个错误" })
		vim.keymap.set("n", "<space>fd", vim.diagnostic.open_float, { desc = "打开浮动窗口查看错误信息" })

		-- 创建 LspAttach 事件的自动命令
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}), -- 创建自动命令组
			callback = function(ev)
				-- 启用 <C-x><C-o> 触发的补全
				vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
				-- 设置缓冲区本地键映射
				local opts = { buffer = ev.buf }
				vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "跳转到变量或函数定义" }, opts)
				vim.keymap.set("n", "ge", vim.lsp.buf.type_definition, { desc = "跳转到类型定义" }, opts)
				vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "跳转到接口实现" }, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, { desc = "查找所有引用" }, opts)
				vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "跳转到声明" }, opts)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "显示悬停信息" }, opts)
				vim.keymap.set(
					{ "n", "i" },
					"<c-k>",
					vim.lsp.buf.signature_help,
					{ desc = "显示函数签名帮助" },
					opts
				)
				vim.keymap.set(
					{ "n", "x" },
					"<space>ca",
					vim.lsp.buf.code_action,
					{ desc = "执行代码操作" },
					opts
				)
				vim.keymap.set({ "n", "v" }, "<space>rn", vim.lsp.buf.rename, { desc = "重命名符号" }, opts)
				vim.keymap.set(
					"n",
					"<space>aw",
					vim.lsp.buf.add_workspace_folder,
					{ desc = "添加工作区目录" },
					opts
				)
				vim.keymap.set(
					"n",
					"<space>rw",
					vim.lsp.buf.remove_workspace_folder,
					{ desc = "移除工作区目录" },
					opts
				)
				vim.keymap.set("n", "<space>lw", function()
					print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
				end, { desc = "列出工作区目录" }, opts)
				-- vim.keymap.set("n", "<S-A-f>", function()
				--     vim.lsp.buf.format({ async = true })
				-- end, { desc = "代码格式化" }, opts)
			end,
		})
	end,
}
