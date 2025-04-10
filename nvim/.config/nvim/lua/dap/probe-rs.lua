-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation

local dap = require("dap")

-- 注册适配器
dap.adapters["probe-rs-debug"] = {
	type = "server",
	port = "${port}",
	executable = {
		command = "/opt/homebrew/bin/probe-rs",
		args = { "dap-server", "--port", "${port}" },
	},
}

-- 获取 ELF 路径（如果是 Rust 项目）
local binary = require("utils.program_binary").get_rust_program_binary

dap.providers.configs["probe-rs"] = function(bufnr)
	return {
		{
			name = "probe_rs Executable launch example",
			type = "probe-rs-debug",
			request = "launch",
			cwd = "${workspaceFolder}",
			runtimeExecutable = "probe-rs",
			runtimeArgs = { "dap-server" },
			chip = "nrf52833_xxAA",
			repl_lang = "javascript",
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
					programBinary = binary, -- ✅ 这里就动态传入
				},
			},

			env = {
				RUST_LOG = "info",
			},

			consoleLogLevel = "Console",
		},
	}
end
require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust" }

local function write_log(message)
	local log_path = vim.fn.getcwd() .. "/probe-rs.log"
	local file = io.open(log_path, "a")
	if file then
		file:write(message .. "\n")
		file:close()
	end
end

-- 监听 RTT 初始化事件，确认窗口开启，否则不会收到数据
dap.listeners.before["event_probe-rs-rtt-channel-config"]["plugins.nvim-dap-probe-rs"] = function(session, body)
	local msg = string.format(
		'%s: Opening RTT channel %d with name "%s"!',
		os.date("%Y-%m-%d-T%H:%M:%S"),
		body.channelNumber,
		body.channelName
	)
	vim.notify(msg, vim.log.levels.INFO)
	write_log(msg)

	session:request("rttWindowOpened", { body.channelNumber, true })
end

-- RTT 数据事件，输出到 REPL 与日志
dap.listeners.before["event_probe-rs-rtt-data"]["plugins.nvim-dap-probe-rs"] = function(_, body)
	local message =
		string.format("%s: RTT-Channel %d - Message: %s", os.date("%Y-%m-%d-T%H:%M:%S"), body.channelNumber, body.data)
	require("dap.repl").append(message)
	write_log(message)
end

-- probe-rs 消息事件
dap.listeners.before["event_probe-rs-show-message"]["plugins.nvim-dap-probe-rs"] = function(_, body)
	local message = string.format("%s: probe-rs message: %s", os.date("%Y-%m-%d-T%H:%M:%S"), body.message)
	require("dap.repl").append(message)
	write_log(message)
end
