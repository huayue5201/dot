-- https://github.com/williamboman/mason-lspconfig.nvim

return {
	"williamboman/mason-lspconfig.nvim",
	cmd = { "Mason", "MasonUpdate", "LspInstall" },
	opts = {
		-- 只接受lsp服务器名称
		ensure_installed = { "lua_ls", "rust_analyzer", "tsserver", "taplo" },
	},
	dependencies = { "williamboman/mason.nvim" },
}
