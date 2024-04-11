-- 定义潜在的项目根文件
local root_files = {
	".luarc.json",
	".luarc.jsonc",
	".luacheckrc",
	".stylua.toml",
	"stylua.toml",
	"selene.toml",
	"selene.yml",
}

-- LSP 配置
local config = {
	name = "lua_ls", -- 语言服务器名称
	cmd = { "lua-language-server", "--stdio" }, -- 启动命令
	root_dir = vim.fs.dirname(vim.fs.find(root_files, { upward = true, stop = vim.env.HOME })[1]), -- 项目根目录
	on_init = function(client)
		local path = client.workspace_folders[1].name
		-- 检查是否存在.luarc.json或.luarc.jsonc文件，若存在则返回
		if vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc") then
			return
		end
		-- 配置 Lua 语言服务器设置
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
	end,
	settings = {
		Lua = {}, -- Lua 语言服务器的其他设置
	},
}

-- 启动 LSP
vim.lsp.start(config, {
	reuse_client = function(client, conf)
		return (client.name == conf.name and (client.config.root_dir == conf.root_dir or conf.root_dir == nil))
	end,
})

-- 调用自定义的 LSP 配置模块
require("util.lspconfig").lspSetup()
