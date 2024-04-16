local utils = require("user.utils")

-- 定义潜在的 Lua 项目根文件
local lua_root_files = {
	".luarc.json",
	".luarc.jsonc",
	".luacheckrc",
	".stylua.toml",
	"stylua.toml",
	"selene.toml",
	"selene.yml",
}

-- 查找项目的根目录
local root_dir = utils.find_root_dir(lua_root_files)

-- Lua LSP 配置
local lua_config = {
	name = "lua_ls",
	cmd = { "lua-language-server", "--stdio" },
	root_dir = root_dir,
	on_init = function(client)
		-- 检查客户端的工作区目录是否存在
		if not client.workspace_folders or not client.workspace_folders[1] then
			return
		end

		local path = client.workspace_folders[1].name
		-- 检查是否存在.luarc.json或.luarc.jsonc文件
		local luarc_exists = vim.fn.filereadable(path .. "/.luarc.json") == 1
			or vim.fn.filereadable(path .. "/.luarc.jsonc") == 1

		-- 如果不存在.luarc.json或.luarc.jsonc文件，则设置 Lua 语言服务器的配置
		if not luarc_exists then
			client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
				runtime = {
					version = "LuaJIT", -- 指定使用的 Lua 版本
				},
				workspace = {
					checkThirdParty = false,
					library = {
						vim.env.VIMRUNTIME, -- 加入 Neovim 的运行时库
					},
				},
			})
		end
	end,
	settings = {
		Lua = {
			hint = {
				enable = true,
			},
			globals = {
				"vim",
			},
		}, -- Lua 语言服务器的其他设置
	},
}

-- 启动 LSP
vim.lsp.start(lua_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
