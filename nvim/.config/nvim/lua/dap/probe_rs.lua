-- https://probe.rs/docs/tools/debugger/

return {
	setup = function(dap)
		dap.adapters["probe-rs-debug"] = {
			type = "server",
			port = "${port}",
			executable = {
				command = "probe-rs",
				args = { "dap-server", "--port", "${port}" },
			},
		}

		-- require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust", "c", "cpp" }

		local config = {
			name = "probe-rs", -- 调试配置名称，VSCode/Neovim DAP UI 中显示的名字
			type = "probe-rs-debug", -- 调试类型，使用 probe-rs 提供的 DAP 接口
			request = "launch", -- 启动方式，"launch" 表示启动新调试会话
			cwd = "${workspaceFolder}", -- 当前工作目录，使用当前项目根目录
			-- NOTE: https://probe.rs/targets/?q=&p=142 支持芯片参考表单
			-- chip = "nrf52833_xxAA",
			-- chip = "STM32F103C8",
			chip = vim.g.selected_chip_config.chip, -- 指定目标芯片型号，必须准确匹配
			flashingConfig = {
				flashingEnabled = true, -- 是否启用烧录（写入 Flash）
				haltAfterReset = true, -- 烧录后是否保持暂停状态
				formatOptions = {
					binaryFormat = "elf", -- 指定二进制文件格式，可选：elf/bin/hex/idf
				},
			},
			coreConfigs = {
				{
					coreIndex = 0, -- 指定核心编号，0 表示第一个核心（适用于多核芯片）
					programBinary = function()
						return require("dap.utils").pick_file() -- 弹出选择框选择 ELF 文件路径
						-- return require("utils.program_binary").safe_get_rust_program_binary("elf") -- 另一种方式：自动获取 rust 编译产物路径
					end,
					svdFile = vim.g.selected_chip_config.svdFile,
					rttEnabled = true, -- 启用 RTT 输出功能（实时日志）
					rttChannelFormats = {
						{
							channelNumber = 0, -- RTT 通道编号
							dataFormat = "String", -- 输出格式为字符串
							showTimestamps = true, -- 显示时间戳
						},
						{
							channelNumber = 1, -- 第二个通道
							dataFormat = "BinaryLE", -- 输出格式为小端二进制
						},
					},
				},
			},
			env = {
				RUST_LOG = "info", -- 设置 RUST_LOG 环境变量，用于 probe-rs 日志调试等级
			},
			consoleLogLevel = "Console", -- 控制台日志输出等级，可为 "Info"、"Debug"、"Console"

			-- probe = vim.g.selected_chip_config.probe, -- （可选）指定具体调试器，如果多个设备可用时手动选择

			runtimeExecutable = "probe-rs", -- （可选）用于启动 DAP 的程序，一般为 probe-rs 可执行文件
			runtimeArgs = { "dap-server" }, -- （可选）传给 runtimeExecutable 的参数，默认为启动 DAP server

			-- speed = 18000, -- （可选）设置通信速度（单位 kHz），如 18000 表示 18MHz
		}

		dap.configurations.rust = { config }
		dap.configurations.c = { config }
		-- dap.configurations.cpp = { config }

		dap.listeners.before["event_probe-rs-rtt-channel-config"]["plugins.nvim-dap-probe-rs"] = function(session, body)
			local utils = require("dap.utils")
			utils.notify(
				string.format('probe-rs: Opening RTT channel %d with name "%s"!', body.channelNumber, body.channelName)
			)
			local file = io.open("probe-rs.log", "a")
			if file then
				file:write(
					string.format(
						'%s: Opening RTT channel %d with name "%s"!\n',
						os.date("%Y-%m-%d-T%H:%M:%S"),
						body.channelNumber,
						body.channelName
					)
				)
			end
			if file then
				file:close()
			end
			session:request("rttWindowOpened", { body.channelNumber, true })
		end

		dap.listeners.before["event_probe-rs-rtt-data"]["plugins.nvim-dap-probe-rs"] = function(_, body)
			local message = string.format(
				"%s: RTT-Channel %d - Message: %s",
				os.date("%Y-%m-%d-T%H:%M:%S"),
				body.channelNumber,
				body.data
			)
			local repl = require("dap.repl")
			repl.append(message)
			local file = io.open("probe-rs.log", "a")
			if file then
				file:write(message)
			end
			if file then
				file:close()
			end
		end

		dap.listeners.before["event_probe-rs-show-message"]["plugins.nvim-dap-probe-rs"] = function(_, body)
			local message = string.format("%s: probe-rs message: %s", os.date("%Y-%m-%d-T%H:%M:%S"), body.message)
			local repl = require("dap.repl")
			repl.append(message)
			local file = io.open("probe-rs.log", "a")
			if file then
				file:write(message)
			end
			if file then
				file:close()
			end
		end
	end,
}
