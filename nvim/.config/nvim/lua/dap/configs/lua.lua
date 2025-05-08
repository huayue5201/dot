return {
	setup = function(dap)
		dap.configurations.lua = {
			{
				name = "Current file (local-lua-dbg, nlua)",
				type = "local-lua",
				request = "launch",
				cwd = "${workspaceFolder}",
				program = {
					lua = "nlua.lua",
					file = "${file}",
				},
				verbose = true,
				args = {},
			},
		}
	end,
}
