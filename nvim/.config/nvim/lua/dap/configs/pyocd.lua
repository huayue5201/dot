return {
	setup = function(dap)
		dap.providers.configs["PyOCD"] = function(bufnr)
			return {
				{
					-- name = "OpenOCD",
					name = "PyOCD",
					type = "cortex-debug",
					request = "launch",
					servertype = "pyocd",
					serverpath = "pyocd",
					-- pid = require("dap.utils").pick_process,
					gdbPath = "arm-none-eabi-gdb",
					-- toolchainPath = "/opt/homebrew/bin",-- 工具链如果在当前系统环境变量中，可以省略
					toolchainPrefix = "arm-none-eabi",
					device = "stm32f103rc", -- 设备型号",
					args = {
						"--target",
						"stm32f103rc", -- 目标设备
						"--interface",
						"stlink", -- 使用 ST-Link 接口
						"--gdb-server",
						"localhost:3333", -- 启动 GDB 服务器
						"--reset", -- 在启动时重置目标设备
					},
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
					-- configFiles = { vim.fn.getcwd() .. "/openocd.cfg" },
					svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
					-- svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
					rttConfig = {
						enabled = true,
						address = "auto",
						decoders = {
							{
								label = "RTT:0",
								port = 0,
								type = "console",
							},
						},
					},
				},
			}
		end
		require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust", "c", "cpp" }
	end,
}
