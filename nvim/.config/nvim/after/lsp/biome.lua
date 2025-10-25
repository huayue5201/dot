return {
	cmd = { "biome", "lsp-proxy" },
	filetypes = {
		"css",
		-- "html",
		-- "javascript",
		-- "javascriptreact",
		"json",
		"jsonc",
		-- "svelte",
		-- "typescript",
		-- "typescriptreact",
	},
	root_markers = { "biome.json", "biome.jsonc" },
	workspace_required = true,
	-- NOTE: dynamic capabilities are kind of a hassle.
	-- https://github.com/neovim/neovim/issues/24229
	capabilities = {
		textDocument = {
			formatting = {
				dynamicRegistration = false,
			},
		},
	},
}
