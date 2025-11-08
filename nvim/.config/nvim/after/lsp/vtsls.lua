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

	on_attach = function(client, bufnr)
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		if line_count > 10000 then
			vim.schedule(function()
				if vim.lsp.buf_is_attached(bufnr, client.id) then
					vim.lsp.buf_detach_client(bufnr, client.id)
					vim.notify("LSP detached for large file (safe delay): " .. vim.api.nvim_buf_get_name(bufnr))
				end
			end)
		end
	end,
}
