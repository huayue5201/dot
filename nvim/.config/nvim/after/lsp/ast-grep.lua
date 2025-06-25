-- https://github.com/ast-grep/ast-grep

return {
	cmd = { "ast-grep", "lsp" },
	filetypes = { -- https://ast-grep.github.io/reference/languages.html
		"html",
		"css",
		"json",
		"yaml",
	},
	root_markers = { "sgconfig.yaml", "sgconfig.yml" },
}
