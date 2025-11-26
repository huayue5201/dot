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
			analyses = {
				unusedparams = true,
			},
			staticcheck = true,
			-- 📁 workspace 设置
			gofumpt = true, -- 更严格的 gofmt（Google 推荐）

			-- ✨语义高亮（类似 semantic）
			semanticTokens = true,
		},
	},
}
