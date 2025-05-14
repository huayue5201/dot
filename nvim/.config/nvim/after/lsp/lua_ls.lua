-- https://github.com/LuaLS/lua-language-server
---@type table<string, vim.lsp.Config>
return {
	cmd = { "lua-language-server" },
	root_markers = {
		".luarc.json",
		".luarc.jsonc",
		".luacheckrc",
		".stylua.toml",
		"stylua.toml",
		"selene.toml",
		"selene.yml",
	},
	filetypes = { "lua" },
	settings = {
		Lua = {
			completion = {
				callSnippet = "Both", -- 代码补全时，函数参数提示
				displayContext = 3, -- 显示上下文行数
			},
			hint = {
				enable = true, -- 启用内联提示
				setPype = true, -- 设置类型
			},
			semantic = {
				enable = true, -- 启用语义高亮
				keywords = true, -- 启用关键字高亮
			},
			telemetry = {
				enable = false,
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
}
