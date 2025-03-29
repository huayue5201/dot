-- https://github.com/jedrzejboczar/nvim-dap-cortex-debug

return {
	"jedrzejboczar/nvim-dap-cortex-debug",
	ft = { "rust", "c" },
	dependencies = "mfussenegger/nvim-dap",
	config = function()
		require("dap-cortex-debug").setup({
			debug = false, -- log debug messages
			-- path to cortex-debug extension, supports vim.fn.glob
			-- by default tries to guess: mason.nvim or VSCode extensions
			-- extension_path = nil,
			lib_extension = nil, -- shared libraries extension, tries auto-detecting, e.g. 'so' on unix
			node_path = "node", -- path to node.js executable
			dapui_rtt = false, -- register nvim-dap-ui RTT element
			-- make :DapLoadLaunchJSON register cortex-debug for C/C++, set false to disable
			dap_vscode_filetypes = { "c", "cpp", "rust" },
			rtt = {
				buftype = "Terminal", -- 'Terminal' or 'BufTerminal' for terminal buffer vs normal buffer
			},
		})

		local dap = require("dap")
		dap.providers.configs["OpenOCD"] = function(bufnr)
			return {
				{
					name = "OpenOCD",
					type = "cortex-debug",
					request = "launch",
					servertype = "openocd",
					serverpath = "openocd",
					-- pid = require("dap.utils").pick_process,
					gdbPath = "arm-none-eabi-gdb",
					-- toolchainPath = "/opt/homebrew/bin",-- 工具链如果在当前系统环境变量中，可以省略
					toolchainPrefix = "arm-none-eabi",
					args = {},
					runToEntryPoint = "main",
					swoConfig = { enabled = false },
					showDevDebugOutput = false,
					gdbTarget = "localhost:3333",
					cwd = "${workspaceFolder}",
					executable = vim.g.debug_file,
					configFiles = { vim.fn.getcwd() .. "/openocd.cfg" },
					svdFile = "",
					rttConfig = {
						address = "auto",
						decoders = {
							{
								label = "RTT:0",
								port = 0,
								type = "console",
							},
						},
					},
				},
			}
		end
	end,
}
