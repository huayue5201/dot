-- https://docs.astral.sh/ty/configuration/#configuration-files

return {
	cmd = { "ty", "server" },
	filetypes = { "python" },
	root_markers = {
		".git/",
		"pyproject.toml",
	},
}
