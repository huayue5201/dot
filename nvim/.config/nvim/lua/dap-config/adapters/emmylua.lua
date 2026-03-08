-- https://github.com/EmmyLua/EmmyLuaDebugger/releases

return {
	setup = function(dap)
		dap.adapters.emmylua = {
			type = "executable",
			command = "/path/to/emmylua_dap",
			args = {},
		}

		dap.configurations.lua = {
			{
				type = "emmylua",
				request = "launch",
				name = "EmmyLua Debug",
				host = "localhost",
				port = 9966,
				sourcePaths = { "path/to/your/workspace" }, -- maybe exist some env variable
				ext = { ".lua" },
				ideConnectDebugger = true,
			},
		}
	end,
}
