-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	event = "VeryLazy",
	dependencies = {
		"Jorenar/nvim-dap-disasm",
	},
	config = function()
		-- repl 自动补全支持
		vim.cmd([[au FileType dap-repl lua require('dap.ext.autocompl').attach()]])

		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF0000" })
		vim.api.nvim_set_hl(0, "DapBreakpointLine", { bg = "#A52A2A" })
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

		require("dap-config.breakpoint_state").setup_autoload()

		require("dap-config.exception-breakpoints")

		-- 🔥 在这里放监听器（最佳位置）
		dap.listeners.after.event_stopped["debug_reason"] = function(session, body)
			print("🔥 STOP reason:", body.reason)
		end

		-- 扩展 REPL 命令
		local repl = require("dap.repl")
		---@diagnostic disable-next-line: inject-field
		repl.commands = vim.tbl_extend("force", repl.commands, {
			-- 添加 .copy 命令
			custom_commands = {
				[".copy"] = function(text)
					local evaluated = repl.execute(text, { context = "clipboard" })
					local result = evaluated.result
					-- 将结果放入系统剪贴板（+寄存器）
					vim.fn.setreg("+", result)
					-- 输出信息到 REPL
					dap.repl.append("Copied to clipboard: " .. result)
				end,
			},
		})

		-- 配置加载方法
		local function load_dap_adapter()
			local filetype = vim.bo.filetype
			if filetype == "rust" then
				-- require("dap-config.adapters.rust-gdb").setup(dap) -- gdb在macOS上有bug
				require("dap-config.adapters.codelldb").setup(dap)
				require("dap-config.adapters.probe_rs").setup(dap)
				-- require("dap-config.adapters.pyocd").setup(dap)
			elseif filetype == "javascript" or filetype == "typescript" then
				-- 如果是 JavaScript 或 TypeScript 文件，加载 vscode-js-debug 适配器
				require("dap-config.adapters.vscode-js-debug").setup(dap)
			elseif filetype == "c" then
				require("dap-config.adapters.probe_rs").setup(dap)
				require("dap-config.adapters.openocd").setup(dap)
				require("dap-config.adapters.pyocd").setup(dap)
			end
		end

		-- 创建自动命令，根据文件类型加载调试适配器
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "*", -- 对所有文件类型生效
			callback = load_dap_adapter, -- 调用加载配置的函数
		})

		vim.api.nvim_create_autocmd({ "VimLeave" }, {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}
