-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	event = "VeryLazy",
	dependencies = {
		"Jorenar/nvim-dap-disasm",
		-- https://github.com/jbyuki/one-small-step-for-vimkind
		"jbyuki/one-small-step-for-vimkind",
		"nvim-dap-extensions",
	},
	config = function()
		-- repl 自动补全支持
		vim.cmd([[au FileType dap-repl lua require('dap.ext.autocompl').attach()]])

		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF0000" })
		vim.api.nvim_set_hl(0, "DapBreakpointLine", { bg = "#5a3c3c" })
		vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#9370DB" })
		vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#8B8B7A" })
		vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#00BFFF" })
		vim.api.nvim_set_hl(0, "YellowCursor", { fg = "#FFCC00", bg = "" })
		vim.api.nvim_set_hl(0, "YellowBack", { bg = "#4C4C19" })
		local signs = {
			DapBreakpoint = { text = "", texthl = "DapBreakpoint", linehl = "DapBreakpointLine" }, -- 断点
			DapBreakpointCondition = { text = "󰽷", texthl = "DapBreakpointCondition", linehl = "DapBreakpointLine" }, -- 条件断点
			DapBreakpointRejected = { text = "", texthl = "DapBreakpointRejected" }, -- 拒绝断点
			DapLogPoint = { text = "󰽷", texthl = "DapLogPoint" }, -- 日志点
			DapStopped = { -- 停止位置
				text = " ",
				texthl = "YellowCursor",
				linehl = "YellowBack",
				numhl = "",
			},
		}
		for name, opts in pairs(signs) do
			vim.fn.sign_define(name, opts)
		end

		local dap = require("dap")

		--  nvim-dap配置
		local dap_defaults = {
			switchbuf = "usevisible,usetab,newtab",
			terminal_win_cmd = "belowright new",
			focus_terminal = true,
			autostart = "nluarepl",
			console = "integratedTerminal",
			stepping_granularity = "statement",
		}

		-- 先赋值普通配置
		for key, value in pairs(dap_defaults) do
			dap.defaults.fallback[key] = value
		end

		-- 单独设置 table 类型的配置
		dap.defaults.fallback.external_terminal = {
			command = "/usr/bin/kitty",
			args = { "-e" },
		}

		require("dap-config.dap_keys").setup()

		require("dap-config.exception-breakpoints")

		-- . 加载 dap-extensions（自定义断点扩展，独立插件）
		require("dap-extensions").setup({
			ui = {
				sign = true, -- 显示符号标记
				virtual_text = true, -- 显示虚拟文本
			},
		})

		require("dap-config.breakpoint_state").setup()

		-- 🔥 在这里放监听器（最佳位置）
		dap.listeners.after.event_stopped["debug_reason"] = function(session, body)
			print("🔥 STOP reason:", body.reason)
		end

		-- 扩展 REPL 命令
		local repl = require("dap.repl")
		---@diagnostic disable-next-line: inject-field
		repl.commands = vim.tbl_extend("force", repl.commands, {
			-- 添加 .copy 命令：求值并把结果放入剪贴板
			custom_commands = {
				[".copy"] = function(text)
					local session = dap.session()
					if not session then
						dap.repl.append("No active debug session")
						return
					end
					session:evaluate(text, function(err, resp)
						if err then
							dap.repl.append(tostring(err))
							return
						end
						local result = resp and resp.result or ""
						vim.fn.setreg("+", result)
						vim.fn.setreg('"', result)
						dap.repl.append("Copied to clipboard: " .. result)
					end)
				end,
			},
		})

		-- 适配器统一在此注册一次（每个 adapter 只 setup 一次，避免重复/覆盖）
		-- gdb 在 macOS 上有 bug，rust-gdb 暂不启用
		require("dap-config.adapters.codelldb").setup(dap)
		require("dap-config.adapters.probe_rs").setup(dap)
		require("dap-config.adapters.vscode-js-debug").setup(dap)
		require("dap-config.adapters.openocd").setup(dap)
		require("dap-config.adapters.pyocd").setup(dap)
		require("dap-config.adapters.nlua").setup(dap)
		require("dap-config.adapters.emmylua").setup(dap)

		vim.api.nvim_create_autocmd({ "VimLeave" }, {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}
