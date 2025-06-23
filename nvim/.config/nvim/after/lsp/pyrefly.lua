-- https://github.com/facebook/pyrefly

return {
	cmd = { "pyrefly", "lsp" },
	filetypes = { "python" },
	root_markers = {
		"setup.py",
		"tox.ini",
		"requirements.txt",
		"Pipfile",
		"pyproject.toml",
		"git",
	},
	root_dir = function(fname)
		return vim.fs.dirname(fname) -- fallback：当前文件夹也作为项目根
	end,
}
