require("lspconfig").clangd.setup({
	cmd = { "clangd", "--background-index" },
	filetypes = { "c", "cpp", "objc", "objcpp" },
	init_options = {
		clangdFileStatus = true,
		usePlaceholders = true,
		completeUnimported = true,
		semanticHighlighting = true,
		format = {
			enable = true,
			format = "file",
			-- style = "Google",
		},
		embeddings = {
			Enable = true,
		},
		embeddings = {
			Enable = true,
		},
	},
})
