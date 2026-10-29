-- https://github.com/microsoft/typescript-go
-- TS 7 的原生（Go）实现，二进制 tsgo：npm i -g @typescript/native-preview
-- 替代 vtsls（基于 tsserver 的 JS 包装），类型检查与补全都快很多；仍是 dev 预览版。

return {
	cmd = { "tsgo", "--lsp", "--stdio" },
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},
	root_markers = {
		{ "tsconfig.json", "jsconfig.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" },
		".git",
	},
}
