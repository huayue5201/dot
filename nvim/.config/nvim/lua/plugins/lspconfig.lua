-- https://github.com/neovim/nvim-lspconfig

-- lsp source列表
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

return {
	"neovim/nvim-lspconfig",
	ft = { "lua", "c", "toml" },
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

		--调用lsp配置模块
		require("util.lsp_set").lspSetup()

		require("lspconfig").lua_ls.setup({
			on_init = function(client)
				local path = client.workspace_folders[1].name
				if vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc") then
					return
				end

				client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
					runtime = {
						-- Tell the language server which version of Lua you're using
						-- (most likely LuaJIT in the case of Neovim)
						version = "LuaJIT",
					},
					-- Make the server aware of Neovim runtime files
					workspace = {
						checkThirdParty = false,
						library = {
							vim.env.VIMRUNTIME,
							-- Depending on the usage, you might want to add additional paths here.
							-- "${3rd}/luv/library"
							-- "${3rd}/busted/library",
						},
						-- or pull in all of 'runtimepath'. NOTE: this is a lot slower
						-- library = vim.api.nvim_get_runtime_file("", true)
					},
				})
			end,
			settings = {
				Lua = {},
			},
		})

		require("lspconfig").clangd.setup({
			cmd = { "clangd", "--background-index" }, -- 使用 clangd 命令，并启用后台索引
			filetypes = { "c", "cpp", "objc", "objcpp" }, -- 文件类型
			init_options = {
				clangdFileStatus = true, -- 启用 clangd 文件状态
				usePlaceholders = true, -- 使用占位符
				completeUnimported = true, -- 自动完成未导入的内容
				semanticHighlighting = true, -- 启用语义高亮
				format = {
					enable = true, -- 启用格式化
					format = "file", -- 格式化方式为文件级别
					-- style = "Google", -- 格式化样式为 Google 风格（可选）
				},
				embeddings = {
					Enable = true, -- 启用嵌入式（可选）
				},
				diagnostic = { enable = false }, -- 禁用错误检查
			},
		})

		require("lspconfig").taplo.setup({})
		-- require("lspconfig").asm_lsp.setup({})
	end,
}
