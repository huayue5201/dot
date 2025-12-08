-- https://probe.rs/docs/tools/debugger/
return {
	setup = function(dap)
		-- probe-rs Adapter 配置
		dap.adapters["probe-rs-debug"] = {
			type = "server",
			port = "${port}",
			executable = {
				command = "probe-rs",
				args = { "dap-server", "--port", "${port}" },
			},
		}

		-- 动态 Provider
		dap.providers.configs["probe-rs-debug"] = function(bufnr)
			local chip = vim.g.envConfig and vim.g.envConfig.chip or nil
			local svdFile = vim.g.envConfig and vim.g.envConfig.svdFile or nil

			local function pick_program()
				return require("dap.utils").pick_file()
			end

			local config = {
				name = "probe-rs",
				type = "probe-rs-debug",
				request = "launch",
				cwd = "${workspaceFolder}",
				chip = chip,
				flashingConfig = {
					flashingEnabled = true,
					haltAfterReset = true,
					formatOptions = { binaryFormat = "elf" },
				},
				coreConfigs = {
					{
						coreIndex = 0,
						programBinary = pick_program,
						svdFile = svdFile,
						rttEnabled = true,
						rttChannelFormats = {
							{ channelNumber = 0, dataFormat = "String", showTimestamps = true },
							{ channelNumber = 1, dataFormat = "BinaryLE" },
						},
					},
				},
				env = { RUST_LOG = "info" },
				consoleLogLevel = "Console",
				runtimeExecutable = "probe-rs",
				runtimeArgs = { "dap-server" },
			}

			return { config }
		end

		-- RTT listeners（保留原逻辑）
		local function log_to_file(msg)
			local f = io.open("probe-rs.log", "a")
			if f then
				f:write(msg .. "\n")
				f:close()
			end
		end

		dap.listeners.before["event_probe-rs-rtt-channel-config"]["plugins.nvim-dap-probe-rs"] = function(session, body)
			local msg = string.format(
				'%s: Opening RTT channel %d "%s"',
				os.date("%Y-%m-%dT%H:%M:%S"),
				body.channelNumber,
				body.channelName
			)
			vim.notify(msg, vim.log.levels.INFO)
			log_to_file(msg)
			session:request("rttWindowOpened", { body.channelNumber, true })
		end

		dap.listeners.before["event_probe-rs-rtt-data"]["plugins.nvim-dap-probe-rs"] = function(_, body)
			local msg =
				string.format("%s: RTT-Channel %d - %s", os.date("%Y-%m-%dT%H:%M:%S"), body.channelNumber, body.data)
			require("dap.repl").append(msg)
			log_to_file(msg)
		end

		dap.listeners.before["event_probe-rs-show-message"]["plugins.nvim-dap-probe-rs"] = function(_, body)
			local msg = string.format("%s: probe-rs message: %s", os.date("%Y-%m-%dT%H:%M:%S"), body.message)
			require("dap.repl").append(msg)
			log_to_file(msg)
		end

		require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust", "c", "cpp" }
	end,
}
