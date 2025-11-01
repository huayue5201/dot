-- https://github.com/microsoft/vscode-js-debug/blob/main/CONTRIBUTING.md

local debug_path = vim.fn.expand("~/vscode-js-debug/src/")

return {
	setup = function(dap)
		-- Node.js 调试适配器
		dap.adapters["pwa-node"] = {
			type = "executable",
			command = "node",
			args = { debug_path .. "/dapDebugServer.ts" },
		}

		-- Chrome 调试适配器
		dap.adapters["pwa-chrome"] = {
			type = "executable",
			command = "node",
			args = { debug_path .. "/dapDebugServer.js" },
		}

		-- JS/TS 调试配置
		local js_ts_launch = {
			{
				name = "Launch file",
				type = "pwa-node",
				request = "launch",
				program = "${file}",
				cwd = vim.fn.getcwd(),
				sourceMaps = true,
				console = "integratedTerminal",
			},
			{
				name = "Attach to Node.js process",
				type = "pwa-node",
				request = "attach",
				-- port = 9229, -- 如果用端口 attach，启动 Node 时加 --inspect=9229
				processId = require("dap.utils").pick_process,
				cwd = vim.fn.getcwd(),
				sourceMaps = true,
			},
		}

		dap.configurations.javascript = js_ts_launch
		dap.configurations.typescript = js_ts_launch

		-- React / 前端调试
		local chrome_config = {
			type = "pwa-chrome",
			request = "launch",
			name = "Launch Chrome against localhost",
			url = "http://localhost:3000",
			webRoot = "${workspaceFolder}",
			sourceMaps = true,
			userDataDir = "/tmp/chrome-dap",
		}

		dap.configurations.javascriptreact = { chrome_config }
		dap.configurations.typescriptreact = { chrome_config }
	end,
}
