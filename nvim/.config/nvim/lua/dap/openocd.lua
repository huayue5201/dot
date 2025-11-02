return {
	setup = function(dap)
		local dap_cortex_debug = require("dap-cortex-debug")

		dap.providers.configs["OpenOCD"] = function(bufnr)
			return {
				{
					name = "OpenOCD",
					type = "cortex-debug",
					request = "launch",
					servertype = "openocd",
					serverpath = "openocd",
					gdbPath = "arm-none-eabi-gdb",
					toolchainPrefix = "arm-none-eabi",
					ajgs = {},
					swoConfig = { enabled = false },
					showDevDebugOutput = false,
					runToEntryPoint = "main",
					cwd = "${workspaceFolder}",
					executable = function()
						return require("dap.utils").pick_file()
					end,
					svdFile = vim.g.envCofnig.svdFile,
					configFiles = vim.g.envCofnig.configFiles,
					rttConfig = dap_cortex_debug.rtt_config(0),
				},
			}
		end
	end,
}
