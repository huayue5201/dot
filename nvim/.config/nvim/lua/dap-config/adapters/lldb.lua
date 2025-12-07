return {
	setup = function(dap)
		dap.adapters.lldb = {
			type = "executable",
			command = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap",
			name = "lldb",
		}
		dap.configurations.rust = {
			{
				name = "Launch",
				type = "lldb",
				request = "launch",
				program = function()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end,
				cwd = "${workspaceFolder}",
				stopOnEntry = false,
				args = {},
			},
			{
				name = "Attach to process",
				type = "cpp",
				request = "attach",
				processId = require("dap.utils").pick_process,
			},
		}
	end,
}
