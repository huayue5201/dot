local project = require("dap-config.project")

return {
	setup = function(dap)
		local dap_cortex_debug = require("dap-cortex-debug")

		dap.providers.configs["OpenOCD"] = function(bufnr)
			if project.kind(bufnr) ~= "embedded" then
				return {}
			end
			local env = project.env_config(bufnr) or {}
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
					svdFile = env.svdFile,
					configFiles = env.configFiles,
					rttConfig = dap_cortex_debug.rtt_config(0),
				},
			}
		end
	end,
}
