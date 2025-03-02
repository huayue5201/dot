return {
	cmd = {
		"rust-analyzer",
	},
	root_markers = { ".git", "Cargo.toml" },
	filetypes = { "rust" },
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
