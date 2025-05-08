-- compiledb.lua
return {
	name = "compiledb make",
	builder = function()
		return {
			cmd = { "compiledb" },
			args = { "make" },
			components = {
				{ "on_output_quickfix", set_diagnostics = false, open = true },
				"default",
			},
		}
		-- vim.lsp.stop_client(vim.lsp.get_clients({ bufnr = 0 })),
		-- vim.defer_fn(function()
		-- 	vim.cmd("edit")
		-- end, 2000)
	end,
	condition = {
		filetype = { "c", "cpp" },
	},
}
