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
	end,
	condition = {
		filetype = { "c", "cpp" },
	},
}
