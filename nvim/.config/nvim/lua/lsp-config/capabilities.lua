-- lua/lsp-config/capabilities.lua
---@brief 全局 LSP client capabilities 与默认 root_markers
local M = {}

function M.setup()
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = true
	capabilities.textDocument.semanticTokens.multilineTokenSupport = true

	local ok, file_ops = pcall(require, "nvim-file-operations.config")
	if ok then
		capabilities = vim.tbl_deep_extend("force", capabilities, file_ops.default_capabilities())
	end

	vim.lsp.config("*", {
		capabilities = capabilities,
		root_markers = { ".git" },
	})
end

return M
