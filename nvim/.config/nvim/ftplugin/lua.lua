vim.lsp.start({
	name = "lua-language-server",
	cmd = { "lua-language-server" },
	root_dir = vim.fs.root(0, {
		".luarc.json",
		".luarc.jsonc",
		".luacheckrc",
		".stylua.toml",
		"stylua.toml",
		"selene.toml",
		"selene.yml",
		".git",
	}),
	filetypes = { "lua" },
	settings = {
		Lua = {
			hint = {
				enable = true, -- 启用代码提示
			},
			codelens = {
				enable = true, -- 启用 CodeLens 功能
			},
			runtime = {
				version = "LuaJIT", -- 指定 Lua 版本
			},
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME, -- 加载 Neovim 的 runtime 文件
				},
				-- 可选：加载所有 runtime 文件（可能会减慢速度）
				-- library = vim.api.nvim_get_runtime_file("", true),
			},
			globals = {
				"vim", -- 声明全局变量 vim
			},
		},
	},
})

-- 调用lsp配置
require("utils.lsp_config").lspSetup()
