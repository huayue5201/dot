local project = require("dap_ext.project")

return {
	setup = function(dap)
		dap.providers.configs["OpenOCD"] = function(bufnr)
			if project.kind(bufnr) ~= "embedded" then
				return {}
			end
			-- 延迟到真正构建嵌入式调试配置时再 require：避免在 nvim-dap 的 config
			-- 期间连锁加载 dap-cortex-debug（它反向依赖 nvim-dap）。
			local dap_cortex_debug = require("dap-cortex-debug")
			local env = project.env_config(bufnr) or {}
			return {
				{
					name = "OpenOCD",
					type = "cortex-debug",
					request = "launch",
					servertype = "openocd",
					serverpath = "openocd",
					gdbPath = "arm-none-eabi-gdb",
					toolchainPrefix = "arm-none-eabi",
					ajgs = {},
					swoConfig = { enabled = false },
					showDevDebugOutput = false,
					runToEntryPoint = "main",
					cwd = "${workspaceFolder}",
					executable = function()
						return require("dap.utils").pick_file()
					end,
					svdFile = env.svdFile,
					configFiles = env.configFiles,
					rttConfig = dap_cortex_debug.rtt_config(0),
				},
			}
		end
	end,
}
