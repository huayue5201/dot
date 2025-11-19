-- TODO:备选 https://github.com/jbyuki/one-small-step-for-vimkind

return {
	setup = function(dap)
		dap.adapters["local-lua"] = {
			type = "executable",
			command = "node",
			args = {
				vim.fs.joinpath(
					vim.fn.stdpath("data"),
					"mason/share/local-lua-debugger-vscode/extension/debugAdapter.js"
				),
			},
		}

		dap.configurations.lua = {
			{
				name = "Launch current file debugging",
				type = "local-lua",
				request = "launch",
				cwd = "${workspaceFolder}",
				extensionPath = vim.fs.joinpath(vim.fn.stdpath("data"), "mason/share/local-lua-debugger-vscode/"),
				program = function()
					return {
						lua = "lua",
						file = vim.api.nvim_buf_get_name(0),
					}
				end,
				verbose = true,
				args = {},
			},
		}
	end,
}
