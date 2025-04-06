-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation
local dap = require("dap")

-- 初始化调试适配器
if not dap.adapters then
	dap.adapters = {}
end

-- 注册调试适配器
dap.adapters["probe-rs-debug"] = {
	name = "probe-rs-debug",
	type = "server",
	port = "${port}",
	executable = {
		command = "probe-rs",
		args = { "dap-server", "--port", "${port}" },
	},
}

dap.adapters.gdb = {
	type = "executable",
	command = "gdb",
	args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
}

dap.adapters.codelldb = {
	type = "executable",
	command = "codelldb", -- 或者指定绝对路径 "/absolute/path/to/codelldb"
}

-- 配置 Rust 调试
dap.configurations.rust = {
	{
		name = "probe-rs",
		type = "probe-rs-debug",
		request = "launch",
		program = vim.g.debug_file, -- 假设 debug_file 变量包含了要调试的程序路径
		cwd = vim.fn.getcwd(), -- 使用当前工作目录
		stopAtEntry = false, -- 不在入口停止
	},
}

-- 配置 C/C++ 调试
dap.configurations.c = {
	{
		name = "gdb Launch",
		type = "gdb",
		request = "launch",
		program = vim.g.debug_file,
		cwd = "${workspaceFolder}",
		stopAtBeginningOfMainSubprogram = false,
	},
}

dap.configurations.cpp = dap.configurations.c -- C++ 配置和 C 配置相同

-- 配置 Codelldb (适用于 Rust 和其他语言)
dap.configurations.rust = vim.list_extend(dap.configurations.rust, {
	{
		name = "codelldb launch",
		type = "codelldb",
		request = "launch",
		program = function()
			return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
		end,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
	},
})

-- 使用 nvim-dap-ext-vscode 来指定文件类型和调试器
require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust" } -- Rust 使用 probe-rs 调试器
require("dap.ext.vscode").type_to_filetypes["gdb"] = { "c", "cpp" } -- C 和 C++ 使用 gdb 调试器
require("dap.ext.vscode").type_to_filetypes["codelldb"] = { "rust", "cpp" } -- Codelldb 可用于 Rust 和 C++

-- 设置监听器处理 RTT 和 probe-rs 消息
dap.listeners.before["event_probe-rs-rtt-channel-config"] = function(session, body)
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
		file:close()
	end
	session:request("rttWindowOpened", { body.channelNumber, true })
end

dap.listeners.before["event_probe-rs-rtt-data"] = function(_, body)
	local message =
		string.format("%s: RTT-Channel %d - Message: %s", os.date("%Y-%m-%d-T%H:%M:%S"), body.channelNumber, body.data)
	local repl = require("dap.repl")
	repl.append(message)
	local file = io.open("probe-rs.log", "a")
	if file then
		file:write(message)
		file:close()
	end
end

dap.listeners.before["event_probe-rs-show-message"] = function(_, body)
	local message = string.format("%s: probe-rs message: %s", os.date("%Y-%m-%d-T%H:%M:%S"), body.message)
	local repl = require("dap.repl")
	repl.append(message)
	local file = io.open("probe-rs.log", "a")
	if file then
		file:write(message)
		file:close()
	end
end
