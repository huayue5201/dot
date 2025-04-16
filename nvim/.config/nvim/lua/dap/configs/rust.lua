return {
	setup = function(dap)
		dap.configurations.rust = {
			{
				name = "Rust (probe-rs)",
				type = "probe-rs-debug",
				request = "launch",
				cwd = "${workspaceFolder}",
				-- runtimeExecutable = "probe-rs",
				-- runtimeArgs = { "dap-server" },
				chip = "nrf52833_xxAA",
				flashingConfig = {
					flashingEnabled = true,
					haltAfterReset = true,
					formatOptions = {
						binaryFormat = "elf",
					},
				},
				coreConfigs = {
					{
						coreIndex = 0,
						programBinary = function()
							return require("utils.program_binary").safe_get_rust_program_binary()
						end,
						svdFile = "",
						rttEnabled = true,
						rttChannelFormats = {
							{
								channelNumber = 0,
								dataFormat = "String", -- 格式化 RTT 数据为字符串
								showTimestamps = true, -- 包括从目标 RTT 输出传输的每行数据的主机端时间戳
							},
							{
								channelNumber = 1,
								dataFormat = "BinaryLE", -- 将数据视为原始二进制数据，不进行格式化
							},
						},
					},
				},
				env = {
					RUST_LOG = "info",
				},
				consoleLogLevel = "Console",
			},
		}
	end,
}
