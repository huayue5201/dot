local dap = require("dap")

-- Configure OpenOCD as the debug adapter
dap.adapters.openocd = {
	type = "executable",
	command = "openocd",
	args = {
		-- "-f",
		-- "board/ti_ek-tm4c123gxl.cfg",
		"-f",
		"interface/stlink.cfg",
		"-f",
		"target/stm32h7x.cfg",
		-- "-c", "program target/thumbv7em-none-eabihf/debug/lets-try-again verify exit"
	},
	gdb_path = "arm-none-eabi-gdb",
}

dap.configurations.rust = {
	{
		type = "openocd",
		request = "launch",
		name = "Debug with OpenOCD",
		executable = function()
			if vim.g.debug_file and vim.fn.filereadable(vim.g.debug_file) == 1 then
				return vim.g.debug_file
			else
				print("No valid debug file set! Please mark a file with <A-b>")
				return ""
			end
		end,
		target = ":3333",
		cwd = "${workspaceFolder}",
		stopAtBeginningOfMainSubprogram = true,
		command = "continue",
	},
}
