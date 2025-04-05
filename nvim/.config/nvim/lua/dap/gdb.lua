local dap = require("dap")

dap.adapters.gdb = {
	type = "executable",
	command = "gdb",
	args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
}

dap.configurations.rust = {
	{
		name = "gdb Launch",
		type = "gdb",
		request = "launch",
		program = vim.g.debug_file,
		cwd = "${workspaceFolder}",
		stopAtBeginningOfMainSubprogram = false,
	},
	{
		name = "Select and attach to process",
		type = "gdb",
		request = "attach",
		program = vim.g.debug_file,
		pid = function()
			local name = vim.fn.input("Executable name (filter): ")
			return require("dap.utils").pick_process({ filter = name })
		end,
		cwd = "${workspaceFolder}",
	},
	{
		name = "Attach to gdbserver :1337",
		type = "gdb",
		request = "attach",
		target = "localhost:1337",
		program = vim.g.debug_file,
		cwd = "${workspaceFolder}",
	},
}
dap.configurations.c = dap.configurations.rust
