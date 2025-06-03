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
					-- device = "stm32f103rc", -- 设备型号",
					ajgs = {},
					swoConfig = { enabled = false },
					showDevDebugOutput = false,
					gdbTarget = "localhost:3333",
					runToEntryPoint = "main",
					-- overrideLaunchCommands = {
					-- 	"monitor reset halt", -- 发送监控命令（复位并挂起目标）
					-- 	"load",
					-- 	"break main",
					-- 	"continue",
					-- },
					cwd = "${workspaceFolder}",
					-- executable = vim.g.debug_file,
					executable = function()
						return require("dap.utils").pick_file()
					end,
					-- configFiles = { vim.fn.getcwd() .. "/openocd.cfg" },
					svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
					-- svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
					configFiles = {
						-- "interface/cmsis-dap.cfg",
						-- "target/nrf52.cfg",
						"interface/stlink.cfg",
						"target/stm32f1x.cfg",
					},
					rttConfig = dap_cortex_debug.rtt_config(0),
					-- rttConfig = {
					-- 	enabled = true,
					-- 	address = "auto",
					-- 	decoders = {
					-- 		{
					-- 			label = "RTT:0",
					-- 			port = 0,
					-- 			type = "console",
					-- 		},
					-- 	},
					-- },
				},
			}
		end
	end,
}
