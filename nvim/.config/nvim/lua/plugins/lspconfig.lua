-- https://github.com/neovim/nvim-lspconfig

-- lsp source列表
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPost", "BufNewFile" },
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
		-- require("lspconfig").asm_lsp.setup({})
		--调用lsp配置模块
		require("util.lsp_config").lspSetup()
	end,
}
