-- https://github.com/golang/tools/tree/master/gopls

---@type table<string, vim.lsp.Config>
return {
	cmd = { "gopls" },
	root_markers = {
		"go.work",
		"go.mod",
		".git",
	},
	filetypes = { "go", "gomod", "gowork" },

	settings = {
		gopls = {
			-- ✨ 自动导入、补全相关
			usePlaceholders = true, -- 填充函数参数
			completeUnimported = true, -- 补全未导入的包
			staticcheck = true, -- 启用 staticcheck 分析
			directoryFilters = { "-.git", "-node_modules", "-dist" },

			-- 🔍 代码分析
			analyses = {
				unusedparams = true,
				unreachable = true,
				shadow = true,
				nilness = true,
			},

			-- 🧠 代码提示 / hints（类似你给的 lua hint 设置）
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				compositeLiteralTypes = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},

			-- 📁 workspace 设置
			gofumpt = true, -- 更严格的 gofmt（Google 推荐）

			-- ✨语义高亮（类似 semantic）
			semanticTokens = true,
		},
	},
}
