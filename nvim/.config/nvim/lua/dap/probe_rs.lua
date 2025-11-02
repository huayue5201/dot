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

		local config = {
			name = "probe-rs",
			type = "probe-rs-debug",
			request = "launch",
			cwd = "${workspaceFolder}",
			chip = vim.g.envCofnig.chip,
			flashingConfig = {
				flashingEnabled = true,
				haltAfterReset = true,
				formatOptions = { binaryFormat = "elf" },
			},
			coreConfigs = {
				{
					coreIndex = 0,
					programBinary = function()
						return require("dap.utils").pick_file()
					end,
					svdFile = vim.g.envCofnig.svdFile,
					rttEnabled = true,
					rttChannelFormats = {
						{ channelNumber = 0, dataFormat = "String", showTimestamps = true },
						{ channelNumber = 1, dataFormat = "BinaryLE" },
					},
				},
			},
			env = { RUST_LOG = "info" },
			consoleLogLevel = "Console",
			-- probe = probe_id, -- 可选
			runtimeExecutable = "probe-rs",
			runtimeArgs = { "dap-server" },
		}

		dap.configurations.rust = { config }
		dap.configurations.c = { config }

		-- RTT listeners
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
	end,
}
