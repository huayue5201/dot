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
				-- 优化 library 路径，避免重复扫描
				library = {
					vim.env.VIMRUNTIME,
					"${3rd}/luv/library",
					-- 只扫描实际存在的目录，避免性能问题
					vim.fn.expand("~/.local/share/nvim/site/pack/*/start/*"),
					vim.fn.expand("~/.local/share/nvim/lazy/*"),
				},
				-- 排除不必要扫描的目录
				ignoreDir = {
					".git",
					".venv",
					"venv",
					"node_modules",
				},
				-- 最大文件数限制（避免内存溢出）
				maxPreload = 1000,
				preloadFileSize = 100,
			},
			diagnostics = {
				globals = { "vim" },
				-- 禁用一些不必要的诊断
				disable = {
					"undefined-global", -- 如果你知道某些全局变量存在
					"unused-function", -- 可选
				},
				-- 启用库诊断
				libraryFiles = "Disable",
			},
			completion = {
				callSnippet = "Replace",
				-- 显示单词长度阈值（避免过多无用建议）
				word = 3,
			},
			-- 内嵌提示（Neovim 0.10+ 推荐使用这个）
			hint = {
				enable = true,
				paramType = true,
				setType = true,
				paramName = "All", -- "All" | "Literal" | "Disable"
				semicolon = "Disable",
				arrayIndex = "Disable",
			},
			-- 代码动作
			codeLens = {
				enable = true,
			},
			-- 格式化（如果你需要）
			format = {
				enable = true,
				defaultConfig = {
					indent_style = "space",
					indent_size = "2",
				},
			},
			-- 性能优化
			telemetry = {
				enable = false,
			},
			-- 可选：Windows 路径兼容
			-- windows = {
			-- 	ignoreDir = { "node_modules" },
			-- },
		},
	},
	-- LSP 附加配置
	-- mason = { ensure_installed = { "lua-language-server" } },
}
