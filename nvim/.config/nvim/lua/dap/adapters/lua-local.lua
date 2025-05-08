-- https://github.com/tomblind/local-lua-debugger-vscode

return {
	setup = function(dap)
		dap.adapters["local-lua"] = {
			type = "executable",
			command = "node",
			args = {
				"~/.local/share/nvim/mason/packages/local-lua-debugger-vscode/extension/extension/debugAdapter.js",
			},
			enrich_config = function(config, on_config)
				if not config["extensionPath"] then
					local c = vim.deepcopy(config)
					-- 💀 If this is missing or wrong you'll see
					-- "module 'lldebugger' not found" errors in the dap-repl when trying to launch a debug session
					c.extensionPath = "/absolute/path/to/local-lua-debugger-vscode/"
					on_config(c)
				else
					on_config(config)
				end
			end,
		}
	end,
}
