-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	ft = { "rust", "c" },
	dependencies = {
		-- https://github.com/igorlfs/nvim-dap-view
		"igorlfs/nvim-dap-view",
		-- https://github.com/theHamsta/nvim-dap-virtual-text
		"theHamsta/nvim-dap-virtual-text",
	},
	config = function()
		-- repl 自动补全支持
		vim.cmd([[  au FileType dap-repl lua require('dap.ext.autocompl').attach()]])

		local signs = {
			DapBreakpoint = { text = "🔴", texthl = "DapBreakpoint" }, -- 断点
			DapBreakpointCondition = { text = "🟡", texthl = "DapBreakpointCondition" }, -- 条件断点
			DapBreakpointRejected = { text = "⭕", texthl = "DapBreakpointRejected" }, -- 拒绝断点
			DapLogPoint = { text = "⚪", texthl = "DapLogPoint" }, -- 日志点
			DapExceptionBreakpoint = { text = "🛑", texthl = "DapExceptionBreakpoint" }, -- 异常断点
			DapStopped = { -- 停止位置
				text = "🔶",
				texthl = "DapBreakpoint",
				linehl = "DapCurrentLine",
				numhl = "DiagnosticSignWarn",
			},
		}
		for name, opts in pairs(signs) do
			vim.fn.sign_define(name, opts)
		end

		-- require("dap.ext.vscode").load_launchjs() -- 和vscode共用配置
		require("dap.probe-rs")
		-- 加载dap调试配置
		local dap = require("dap")

		dap.defaults.fallback.terminal_win_cmd = "belowright new" -- 设置终端窗口命令
		dap.defaults.fallback.focus_terminal = true -- 打开终端时将焦点放在终端窗口

		-- 设置默认终端为外部终端（例如使用 alacritty）
		dap.defaults.fallback.external_terminal = {
			command = "/usr/bin/alacritty",
			args = { "-e" },
		}

		-- 自动启动 REPL
		dap.defaults.fallback.autostart = "nluarepl"

		require("nvim-dap-virtual-text").setup()
		local dv = require("dap-view")

		dv.setup = {
			winbar = {
				show = true,
				sections = { "watches", "exceptions", "breakpoints", "threads", "repl" },
				-- Must be one of the sections declared above
				default_section = "watches",
			},
			windows = {
				height = 12,
				terminal = {
					-- 'left'|'right'|'above'|'below': Terminal position in layout
					position = "left",
					-- List of debug adapters for which the terminal should be ALWAYS hidden
					hide = {},
					-- Hide the terminal when starting a new session
					start_hidden = true,
				},
			},
		}

		dap.listeners.before.attach["dap-view-config"] = function()
			dv.open()
		end
		dap.listeners.before.launch["dap-view-config"] = function()
			dv.open()
		end
		dap.listeners.before.event_terminated["dap-view-config"] = function()
			dv.close()
		end
		dap.listeners.before.event_exited["dap-view-config"] = function()
			dv.close()
		end

		vim.keymap.set("n", "<leader>dv", function()
			require("dap-view").toggle()
		end, { desc = "Toggle nvim-dap-view" })

		vim.keymap.set("n", "<leader>od", dap.continue, { silent = true, desc = "启动调试" })
		-- vim.keymap.set("n", "<leader>od", dap.run, { silent = true, desc = "启动新的调试" })

		-- vim.keymap.set("n", "<leader>da", function()
		-- 	print(vim.inspect(require("dap").session())) -- 或者使用浮动窗口显示
		-- end, { silent = true, desc = "显示调试会话" })

		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { silent = true, desc = "断点" })

		vim.keymap.set("n", "<leader>ob", function()
			vim.ui.select({ "condition", "log", "exception" }, {
				prompt = "选择断点类型:",
			}, function(choice)
				if choice == "condition" then
					vim.ui.input({ prompt = "断点条件: " }, function(condition)
						dap.set_breakpoint(condition)
					end)
				elseif choice == "log" then
					vim.ui.input({ prompt = "日志点消息: " }, function(message)
						dap.set_breakpoint(nil, nil, message)
					end)
				elseif choice == "exception" then
					dap.set_exception_breakpoints()
				else
					vim.notify("无效的选择！", vim.log.levels.ERROR)
				end
			end)
		end, { desc = "设置断点（条件、日志、异常）" })

		-- vim.keymap.set("n", "<leader>bp", function()
		-- 	vim.ui.input({ prompt = "断点条件: " }, function(input)
		-- 		require("dap").set_breakpoint(input)
		-- 	end)
		-- end, { desc = "条件断点" })
		--
		-- vim.keymap.set("n", "<Leader>bl", function()
		-- 	dap.set_breakpoint(nil, nil, vim.fn.input("日志点消息: "))
		-- end, { silent = true, desc = "日志点" })
		--
		-- vim.keymap.set("n", "<leader>be", dap.set_exception_breakpoints, { silent = true, desc = "异常断点" })

		vim.keymap.set("n", "<leader>rb", dap.clear_breakpoints, { silent = true, desc = "移除所有断点" })

		vim.keymap.set("n", "<leader>rd", dap.terminate, { silent = true, desc = "终止dap会话" })

		vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "运行上次调试会话" })

		vim.keymap.set("n", "<leader>do", dap.step_over, { silent = true, desc = "单步跳过" })

		vim.keymap.set("n", "<leader>di", dap.step_into, { silent = true, desc = "单步进入" })

		vim.keymap.set("n", "<leader>du", dap.step_out, { silent = true, desc = "单步跳出" })

		vim.keymap.set("n", "<leader>dd", dap.pause, { silent = true, desc = "暂停调试线程" })

		-- vim.keymap.set("n", "<leader>du", dap.step_back, { silent = true, desc = "逆向调试" })
		-- vim.keymap.set("n", "<leader>du", dap.reverse_continue, { silent = true, desc = "逆向到最后一个断点" })
		-- vim.keymap.set("n", "<leader>drf", dap.restart_frame, { silent = true, desc = "重新执行堆栈帧" })
		-- vim.keymap.set("n", "[", dap.up, { silent = true, desc = "跳到上一个断点" })
		-- vim.keymap.set("n", "]", dap.down, { silent = true, desc = "跳到一个断点" })
		-- vim.keymap.set("n", "]", dap.goto_, { silent = true, desc = "跳到指定行" })

		vim.keymap.set("n", "<leader>dc", dap.run_to_cursor, { silent = true, desc = "运行到光标处" })

		vim.keymap.set("n", "<leader>dq", dap.list_breakpoints, { silent = true, desc = "列出所有断点" })

		vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { silent = true, desc = "DAP REPL" })
		-- vim.keymap.set("n", "<leader>da", dap.repl.exetuce(命令或者表达式，可以直接在repl中执行), { silent = true, desc = "在 REPL 中运行代码" })

		local widgets = require("dap.ui.widgets")

		vim.keymap.set("n", "<leader>dk", function()
			widgets.hover(nil, { border = "rounded" })
		end, { desc = "查看变量值" })

		vim.keymap.set("n", "<leader>ds", function()
			widgets.cursor_float(widgets.scopes, { border = "shadow" })
		end, { desc = "显示当前调试会话中的所有作用域" })

		vim.keymap.set("n", "<leader>de", function()
			widgets.cursor_float(widgets.sessions, { border = "shadow" })
		end, { desc = "显示所有当前调试会话" })

		vim.keymap.set("n", "<leader>dx", function()
			widgets.cursor_float(widgets.expression, { border = "shadow" })
		end, { desc = "显示光标下表达式的值" })

		vim.keymap.set("n", "<leader>dt", function()
			widgets.cursor_float(widgets.threads, { border = "shadow" })
		end, { desc = "显示当前会话中的所有线程" })

		vim.keymap.set("n", "<leader>df", function()
			widgets.cursor_float(widgets.frames, { border = "rounded" })
		end, { desc = "查看堆栈" })

		local api = vim.api
		local keymap_restore = {}
		dap.listeners.after["event_initialized"]["me"] = function()
			for _, buf in pairs(api.nvim_list_bufs()) do
				local keymaps = api.nvim_buf_get_keymap(buf, "n")
				for _, keymap in pairs(keymaps) do
					if keymap.lhs == "K" then
						table.insert(keymap_restore, keymap)
						api.nvim_buf_del_keymap(buf, "n", "K")
					end
				end
			end
			api.nvim_set_keymap("n", "K", '<Cmd>lua require("dap.ui.widgets").hover()<CR>', { silent = true })
		end
		dap.listeners.after["event_terminated"]["me"] = function()
			for _, keymap in pairs(keymap_restore) do
				if keymap.rhs then
					api.nvim_buf_set_keymap(
						keymap.buffer,
						keymap.mode,
						keymap.lhs,
						keymap.rhs,
						{ silent = keymap.silent == 1 }
					)
				elseif keymap.callback then
					vim.keymap.set(
						keymap.mode,
						keymap.lhs,
						keymap.callback,
						{ buffer = keymap.buffer, silent = keymap.silent == 1 }
					)
				end
			end
			keymap_restore = {}
		end

		dap.listeners.after["event_terminated"]["terminate"] = function()
			require("dap-view").close(true)
			require("dap").repl.close()
			print("调试已终止，关闭 REPL")
		end

		-- 退出neovim自动终止调试进程
		vim.api.nvim_create_autocmd("VimLeave", {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})

		-- TODO:
		-- session() dap.session()
		-- 返回当前的调试会话，如果没有会话则返回 nil。
		-- status()
		-- 返回当前调试会话的状态文本。
		-- 如果没有活动的调试会话，结果将为空。
	end,
}
