-- https://github.com/microsoft/vscode-js-debug/blob/main/CONTRIBUTING.md

return {
	setup = function(dap)
		-- Node.js 调试适配器
		dap.adapters = {
			["pwa-node"] = {
				type = "server",
				port = "${port}",
				executable = {
					command = "js-debug-adapter",
					args = {
						"${port}",
					},
				},
				-- resolveSourceMapLocations = { "${workspaceFolder}/build/**/*.js", "!**/node_modules/**" },
				-- skipFiles = { "<node_internals>/**", "node_modules/**" },
			},

			-- -- Chrome 调试适配器
			["pwa-chrome"] = {
				type = "executable",
				command = "node",
				args = { "${port}" },
			},
		}

		-- JS/TS 调试配置
		local js_ts_launch = {
			{
				type = "pwa-node",
				request = "launch",
				name = "Launch file",
				program = "${file}",
				cwd = "${workspaceFolder}",
			},
			{
				type = "pwa-node",
				request = "attach",
				name = "Attach to process ID",
				-- processId = utils.pick_process,
				cwd = "${workspaceFolder}",
			},
		}

		dap.configurations.javascript = js_ts_launch
		dap.configurations.typescript = js_ts_launch

		-- React / 前端调试
		-- local chrome_config = {
		-- 	type = "pwa-chrome",
		-- 	request = "launch",
		-- 	name = "Launch Chrome against localhost",
		-- 	url = "http://localhost:3000",
		-- 	webRoot = "${workspaceFolder}",
		-- 	sourceMaps = true,
		-- 	userDataDir = "/tmp/chrome-dap",
		-- }

		-- dap.configurations.javascriptreact = { chrome_config }
		-- dap.configurations.typescriptreact = { chrome_config }
	end,
}
