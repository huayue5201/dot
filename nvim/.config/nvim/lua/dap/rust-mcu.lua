local dap = require("dap")

dap.adapters.gdb = {
	type = "executable",
	command = "arm-none-eabi-gdb", -- GDB 的路径
	name = "gdb",
	args = { "-q" },
}

dap.configurations.rust = {
	{
		name = "Debug - OpenOCD",
		type = "cortex-debug",
		request = "launch",
		servertype = "openocd",
		serverpath = "openocd",
		gdbPath = "C:/Development/Toolchain/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi-gdb.exe",
		device = "STM32WB55CGU6",
		interface = "swd",
		toolchainPrefix = "C:/Development/Toolchain/gcc-arm-none-eabi-10.3-2021.10/bin/arm-none-eabi",
		runToEntryPoint = "main",
		swoConfig = { enabled = false },
		showDevDebugOutput = true,
		gdbTarget = "localhost:3333",
		cwd = "${workspaceFolder}",
		executable = "${workspaceFolder}/Output/build/firmware.axf",
		configFiles = {
			"C:/Development/Toolchain/OpenOCD-20231002-0.12.0/share/openocd/scripts/interface/stlink.cfg",
			"C:/Development/Toolchain/OpenOCD-20231002-0.12.0/share/openocd/scripts/target/stm32wbx.cfg",
		},
		preLaunchCommands = {},
		overrideLaunchCommands = {
			"cd Output/build",
			"file firmware.hex",
			"target extended-remote localhost:50000",
			"monitor reset halt",
			"load firmware.hex",
			-- "set output-radix 16"
		},
		rttConfig = {
			address = "auto",
			decoders = {
				{
					label = "RTT:0",
					port = 0,
					type = "console",
				},
			},
			enabled = true,
		},
	},
}

-- dap.configurations.rust = {
-- 	{
-- 		name = "Debug STM32",
-- 		type = "gdb",
-- 		request = "launch",
-- 		program = function()
-- 			-- 获取当前 Rust 项目名（默认 ELF 文件名）
-- 			local cargo_toml = vim.fn.getcwd() .. "/Cargo.toml"
-- 			local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t") -- 取当前目录名作为项目名
-- 			-- 解析 Cargo.toml 以获取 `[package] name = "xxx"`
-- 			if vim.fn.filereadable(cargo_toml) == 1 then
-- 				for _, line in ipairs(vim.fn.readfile(cargo_toml)) do
-- 					local name = line:match('^name%s*=%s*"(.-)"')
-- 					if name then
-- 						project_name = name
-- 						break
-- 					end
-- 				end
-- 			end
-- 			-- 构造 ELF 文件路径
-- 			local exe_path = vim.fn.getcwd() .. "/target/thumbv7em-none-eabi/debug/" .. project_name
-- 			-- 如果 ELF 存在，直接返回，否则手动输入
-- 			return vim.fn.filereadable(exe_path) == 1 and exe_path
-- 				or vim.fn.input("Path to executable: ", exe_path, "file")
-- 		end,
-- 		cwd = "${workspaceFolder}", -- 项目文件夹
-- 		target = "localhost:3333", -- OpenOCD 调试端口
-- 		MIMode = "gdb",
-- 		miDebuggerPath = "arm-none-eabi-gdb", -- 设置 gdb 的路径
-- 		setupCommands = {
-- 			{
-- 				description = "Enable pretty-printing for gdb",
-- 				text = "-enable-pretty-printing",
-- 				ignoreFailures = false,
-- 			},
-- 		},
-- 		stopAtEntry = true, -- 是否在程序入口处暂停
-- 		args = {}, -- 你可以传递调试时的参数
-- 	},
-- }
