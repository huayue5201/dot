return {
	setup = function(dap)
		-- Mason 安装路径
		local mason_path = vim.fn.stdpath("data") .. "/mason/packages/local-lua-debugger-vscode"

		-- 配置 Lua 调试适配器
		dap.adapters.lua = function(callback, config)
			callback({
				type = "server",
				host = config.host or "127.0.0.1",
				port = config.port or 9000,
			})
		end

		-- 配置 Lua 调试配置
		dap.configurations.lua = {
			{
				type = "lua",
				request = "launch",
				name = "Debug current file",
				program = function()
					return vim.fn.input("Path to file: ", vim.fn.expand("%"), "file")
				end,
				cwd = "${workspaceFolder}",
				runtimeExecutable = "lua",
				runtimeArgs = {
					"-e",
					"require('lldebugger').start()",
					mason_path .. "/extension/debugAdapter.lua",
				},
				port = 9000,
				host = "127.0.0.1",
			},
		}
	end,
}
