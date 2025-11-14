-- https://github.com/yioneko/vtsls
-- npm install -g @vtsls/language-server

return {
	cmd = { "vtsls", "--stdio" },
	init_options = {
		hostInfo = "neovim",
	},
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},
	root_markers = {
		{ "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
		".git",
	},
}
