-- lua_root_files参考：https://github.com/neovim/nvim-lspconfig/tree/4a69ad6646eaad752901413c9a0dced73dfb562d/lua/lspconfig/server_configurations

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
	settings = {
		Lua = {
			version = "LuaJIT", -- 指定使用的 Lua 版本
			workspace = {
				checkThirdParty = false,
			},
			codeLens = {
				enable = true,
			},
			completion = {
				callSnippet = "Replace",
			},
			doc = {
				privateName = { "^_" },
			},
			hint = {
				enable = true,
				setType = false,
				paramType = true,
				paramName = "Disable",
				semicolon = "Disable",
				arrayIndex = "Disable",
			},
			globals = {
				"vim",
			},
		},
	},
}

-- 启动 LSP
vim.lsp.start(lua_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
