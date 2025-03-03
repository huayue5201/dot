-- https://rust-analyzer.github.io/

return {
	cmd = {
		"rust-analyzer",
	},
	root_markers = { "Cargo.toml" },
	filetypes = { "rust" },
	single_file_support = true,
	settings = {
		["rust-analyzer"] = {
			imports = {
				granularity = {
					group = "module",
				},
				prefix = "self",
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
			},
			procMacro = {
				enable = true,
			},
		},
	},
}
