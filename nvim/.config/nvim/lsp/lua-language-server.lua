-- https://github.com/LuaLS/lua-language-server

return {
	cmd = { "lua-language-server" },
	root_markers = {
		".luarc.json",
		".luarc.jsonc",
		".luacheckrc",
		".stylua.toml",
		"selene.toml",
		"selene.yml",
		".git",
	},
	filetypes = { "lua" },
	single_file_support = true,
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
				path = vim.split(package.path, ";"),
			},
			workspace = {
				checkThirdParty = false,
				library = {
					vim.env.VIMRUNTIME,
					"${3rd}/luv/library",
					vim.fn.expand("~/.local/share/nvim/site/pack/*/start/*"),
				},
			},
			diagnostics = {
				globals = { "vim" },
			},
			completion = {
				callSnippet = "Replace",
			},
			telemetry = {
				enable = false,
			},
			-- 新增：开启嵌入提示
			hint = {
				enable = true, -- 启用所有提示
				paramType = true, -- 参数类型提示
				setType = true, -- 设置类型提示
				paramName = "All", -- 显示参数名
				semicolon = "Disable", -- 分号提示（默认禁用）
				arrayIndex = "Disable", -- 数组索引提示（默认禁用）
			},
			-- 新增：内联提示（Neovim 0.5+ 支持）
			inlayHints = {
				enable = true, -- 启用内联提示
				showParameterName = true, -- 显示参数名
				showVariableType = true, -- 显示变量类型
				showFunctionReturnType = true, -- 显示函数返回类型
			},
		},
	},
}
