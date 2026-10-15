local project = require("dap-config.project")

return {
	setup = function(dap)
		dap.providers.configs["OpenOCD"] = function(bufnr)
			if project.kind(bufnr) ~= "embedded" then
				return {}
			end
			-- 延迟到真正构建嵌入式调试配置时再加载：dap-cortex-debug 依赖 nvim-dap，
			-- 若在 nvim-dap 的 config 期间 require，会触发 zpack 的循环依赖告警。
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
