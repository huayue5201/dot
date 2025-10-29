-- https://github.com/microsoft/vscode-js-debug/blob/main/CONTRIBUTING.md

return {
	setup = function(dap)
		-- === Node.js 调试 ===
		dap.adapters.node2 = {
			type = "executable",
			command = "node",
			args = { vim.fn.expand("~/vscode-js-debug/src/dapDebugServer.ts") },
		}

		dap.configurations.javascript = {
			{
				name = "Launch Node.js file",
				type = "node2",
				request = "launch",
				program = "${file}", -- 当前文件
				cwd = "${workspaceFolder}",
				sourceMaps = true,
				protocol = "inspector",
				console = "integratedTerminal",
			},
			{
				name = "Attach to Node.js process",
				type = "node2",
				request = "attach",
				processId = require("dap.utils").pick_process,
				cwd = "${workspaceFolder}",
			},
		}

		-- === TypeScript 调试（如果用 ts-node 或编译后调试） ===
		dap.configurations.typescript = {
			{
				name = "Launch TS file",
				type = "node2",
				request = "launch",
				program = "${file}",
				cwd = "${workspaceFolder}",
				sourceMaps = true,
				protocol = "inspector",
				runtimeArgs = { "--loader", "ts-node/esm" },
				console = "integratedTerminal",
			},
		}

		-- === Chrome / 前端调试 ===
		dap.adapters.chrome = {
			type = "executable",
			command = "node",
			args = { vim.fn.expand("~/vscode-js-debug/src/dapDebugServer.ts") },
		}

		dap.configurations.typescriptreact = {
			{
				type = "chrome",
				request = "launch",
				name = "Launch Chrome against localhost",
				url = "http://localhost:3000",
				webRoot = "${workspaceFolder}",
				sourceMaps = true,
				userDataDir = "/tmp/chrome-dap",
			},
		}

		dap.configurations.javascriptreact = dap.configurations.typescriptreact
	end,
}
