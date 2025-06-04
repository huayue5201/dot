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
					-- pid = require("dap.utils").pick_process,
					gdbPath = "arm-none-eabi-gdb",
					-- toolchainPath = "/opt/homebrew/bin",-- 工具链如果在当前系统环境变量中，可以省略
					toolchainPrefix = "arm-none-eabi",
					ajgs = {},
					swoConfig = { enabled = false },
					showDevDebugOutput = false,
					-- gdbTarget = "localhost:3333",
					runToEntryPoint = "main",
					-- overrideLaunchCommands = {
					-- 	"monitor reset halt", -- 发送监控命令（复位并挂起目标）
					-- 	"load",
					-- 	"break main",
					-- 	"continue",
					-- },
					cwd = "${workspaceFolder}",
					executable = function()
						return require("dap.utils").pick_file()
					end,
					svdFile = vim.g.selected_chip_config.svdFile,
					configFiles = vim.g.selected_chip_config.configFiles,
					rttConfig = dap_cortex_debug.rtt_config(0),
				},
			}
		end
	end,
}
