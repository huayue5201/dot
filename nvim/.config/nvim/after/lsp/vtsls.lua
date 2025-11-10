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
		local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
		local file_size_mb = (ok and stats and stats.size or 0) / (1024 * 1024) -- 转换成 MB

		local BIGFILE_LINES = 100000
		local BIGFILE_SIZE = 3 -- MB

		if line_count > BIGFILE_LINES or file_size_mb > BIGFILE_SIZE then
			vim.schedule(function()
				if vim.lsp.buf_is_attached(bufnr, client.id) then
					vim.lsp.buf_detach_client(bufnr, client.id)
					vim.notify(
						string.format(
							"🌐vtsls: LSP detached for large file: %s (%d lines, %.2f MB)",
							vim.api.nvim_buf_get_name(bufnr),
							line_count,
							file_size_mb
						)
					)
				end
			end)
		end
	end,
}
