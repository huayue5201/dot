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

		require("dap").configurations.rust = {
			{
				name = "Example debugging with OpenOCD",
				type = "cortex-debug",
				-- request = "attach",
				request = "launch",
				repl_lang = "rust",
				-- pid = require("dap.utils").pick_process,
				servertype = "openocd",
				serverpath = "openocd",
				gdbPath = "arm-none-eabi-gdb",
				-- toolchainPath = "/opt/homebrew/bin",-- 工具链如果在当前系统环境变量中，可以省略
				toolchainPrefix = "arm-none-eabi",
				args = {}, -- 传递给调试会话的额外参数，当前为空
				runToEntryPoint = "main",
				swoConfig = { enabled = false },
				showDevDebugOutput = false,
				gdbTarget = "localhost:3333",
				cwd = "${workspaceFolder}",
				executable = function()
					if vim.g.debug_file and vim.fn.filereadable(vim.g.debug_file) == 1 then
						return vim.g.debug_file
					else
						print("No valid debug file set! Please mark a file with <A-b>")
						return ""
					end
				end,
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
	end,
}
