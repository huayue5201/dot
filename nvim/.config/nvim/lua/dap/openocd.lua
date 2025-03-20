local dap = require("dap")
dap.adapters["openocd"] = {
	type = "server",
	host = "127.0.0.1",
	port = 3333,
}

dap.configurations.rust = {
	{
		name = "Debug with OpenOCD",
		type = "openocd",
		request = "attach",
		cwd = "${workspaceFolder}",
		gdbPath = "arm-none-eabi-gdb",
		gdbTarget = "localhost:3333",
		executable = function()
			if vim.g.debug_file and vim.fn.filereadable(vim.g.debug_file) == 1 then
				return vim.g.debug_file
			else
				print("No valid debug file set! Please mark a file with <A-b>")
				return ""
			end
		end,
		stopAtEntry = true,
		timeout = 10000, -- 10 秒
	},
}
