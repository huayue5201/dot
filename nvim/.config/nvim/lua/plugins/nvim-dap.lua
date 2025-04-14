-- https://github.com/mfussenegger/nvim-dap
-- TODO: https://github.com/mfussenegger/nvim-dap/issues/1388

return {
	"mfussenegger/nvim-dap",
	ft = { "rust", "c", "lua" },
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
			-- DapExceptionBreakpoint = { text = "🛑", texthl = "DapExceptionBreakpoint" }, -- 异常断点🔻
			DapStopped = { -- 停止位置
				text = "🎯", --🟨🔶
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
		-- require("utils.debug-file-manager") -- 调试文件标记模块
		local dap = require("dap")

		local dap_defaults = {
			switchbuf = "useopen", -- 在调试时使用打开的缓冲区
			terminal_win_cmd = "belowright new", -- 设置终端窗口在底部打开
			focus_terminal = true, -- 打开终端时将焦点切换到终端
			autostart = "nluarepl", -- 自动启动 Lua REPL
			console = "integratedTerminal", -- 控制台设置
			external_terminal = {
				command = "/usr/bin/alacritty", -- 外部终端的命令路径
				args = { "-e" }, -- 外部终端的参数
			},
		}
		-- 将配置应用到 dap.defaults.fallback
		for key, value in pairs(dap_defaults) do
			dap.defaults.fallback[key] = value
		end

		require("nvim-dap-virtual-text").setup()
		local dv = require("dap-view")

		dv.setup({
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
					position = "right",
					-- List of debug adapters for which the terminal should be ALWAYS hidden
					hide = { "OpenOCD" },
					-- Hide the terminal when starting a new session
					start_hidden = true,
				},
			},
		})

		-- dap.listeners.before.attach["dap-view-config"] = function()
		-- 	dv.open()
		-- end
		-- dap.listeners.before.launch["dap-view-config"] = function()
		-- 	dv.open()
		-- end
		-- dap.listeners.before.event_terminated["dap-view-config"] = function()
		-- 	dv.close()
		-- end
		-- dap.listeners.before.event_exited["dap-view-config"] = function()
		-- 	dv.close()
		-- end

		vim.keymap.set("n", "<leader>dv", function()
			require("dap-view").toggle()
		end, { desc = "切换 nvim-dap-view" })

		vim.g.repeatable_map("n", "<leader>dc", dap.continue, { silent = true, desc = "继续/启动调试" })

		vim.keymap.set("n", "<leader>du", dap.run, { silent = true, desc = "启动新调试会话" })

		vim.keymap.set("n", "<leader>rd", function()
			dap.terminate({
				on_done = function()
					require("dap").repl.close()
					require("dap-view").close(true)
				end,
			})
		end, { silent = true, desc = "终止调试" })

		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { silent = true, desc = "切换断点" })

		vim.keymap.set("n", "<leader>B", function()
			vim.ui.select({ "条件断点", "命中次数", "日志点", "异常断点" }, {
				prompt = "选择断点类型:",
			}, function(choice)
				if choice == "条件断点" then
					vim.ui.input({ prompt = " 󰌓 输入条件: " }, function(condition)
						dap.set_breakpoint(condition)
					end)
				elseif choice == "命中次数" then
					vim.ui.input({ prompt = " 󰌓 输入次数: " }, function(hit_count)
						if hit_count and tonumber(hit_count) then
							dap.set_breakpoint(nil, tonumber(hit_count), nil)
						else
							vim.notify("无效输入!", vim.log.levels.ERROR)
						end
					end)
				elseif choice == "日志点" then
					vim.ui.input({ prompt = " 󰌓 输入日志内容: " }, function(message)
						dap.set_breakpoint(nil, nil, message)
					end)
				elseif choice == "异常断点" then
					dap.set_exception_breakpoints()
				else
					vim.notify("无效选择！", vim.log.levels.ERROR)
				end
			end)
		end, { desc = "设置断点" })

		vim.keymap.set("n", "<leader>rb", dap.clear_breakpoints, { silent = true, desc = "清除所有断点" })

		vim.keymap.set("n", "<leader>drl", dap.run_last, { desc = "运行上次会话" })

		vim.g.repeatable_map("n", "<leader>dro", dap.step_over, { silent = true, desc = "单步跳过" })

		vim.g.repeatable_map("n", "<leader>dri", dap.step_into, { silent = true, desc = "单步进入" })

		vim.g.repeatable_map("n", "<leader>dru", dap.step_out, { silent = true, desc = "单步跳出" })

		vim.g.repeatable_map("n", "<leader>drb", dap.step_back, { silent = true, desc = "逆向单步" })

		vim.keymap.set("n", "<leader>drc", dap.run_to_cursor, { silent = true, desc = "运行到光标" })

		vim.keymap.set("n", "<leader>drc", dap.reverse_continue, { silent = true, desc = "逆向继续" })

		vim.keymap.set("n", "<leader>drf", dap.restart_frame, { silent = true, desc = "重启当前帧" })

		vim.keymap.set("n", "<leader>dd", dap.pause, { silent = true, desc = "暂停线程" })

		vim.g.repeatable_map("n", "[.", dap.up, { silent = true, desc = "上一个断点" })

		vim.g.repeatable_map("n", "].", dap.down, { silent = true, desc = "下一个断点" })

		vim.keymap.set("n", "<leader>dgn", function()
			vim.ui.input({ prompt = " 󰙎输入行号: " }, function(input)
				if input then
					-- 将用户输入的行号传递给 dap.goto_
					local line = tonumber(input)
					if line then
						dap.goto_(line)
					else
						print("无效的行号")
					end
				end
			end)
		end, { silent = true, desc = "跳转到行" })

		vim.keymap.set("n", "<leader>dR", dap.repl.toggle, { silent = true, desc = "切换 REPL" })

		vim.keymap.set("n", "<leader>dlq", dap.list_breakpoints, { silent = true, desc = "查看所有断点" })

		local widgets = require("dap.ui.widgets")

		vim.keymap.set("n", "<leader>dlk", function()
			widgets.hover(nil, { border = "rounded" })
		end, { desc = "查看变量" })

		vim.keymap.set("n", "<leader>dlc", function()
			widgets.cursor_float(widgets.scopes, { border = "rounded" })
		end, { desc = "查看作用域" })

		vim.keymap.set("n", "<leader>dls", function()
			widgets.cursor_float(widgets.sessions, { border = "rounded" })
		end, { desc = "查看调试会话" })

		vim.keymap.set("n", "<leader>dle", function()
			widgets.cursor_float(widgets.expression, { border = "rounded" })
		end, { desc = "查看表达式值" })

		vim.keymap.set("n", "<leader>dlt", function()
			widgets.cursor_float(widgets.threads, { border = "rounded" })
		end, { desc = "查看线程" })

		vim.keymap.set("n", "<leader>dlf", function()
			widgets.cursor_float(widgets.frames, { border = "rounded" })
		end, { desc = "查看堆栈" })

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "dap-repl",
			group = vim.api.nvim_create_augroup("dapui_keymaps", { clear = true }),
			desc = "Fix and add insert-mode keymaps for dap-repl",
			callback = function()
				vim.cmd("syntax on") -- 启用语法高亮（保险）
				vim.cmd("runtime! syntax/rust.vim") -- 手动加载 Rust 的语法文件
				-- 向下浏览补全项
				vim.keymap.set("i", "<tab>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-n>" -- Trigger completion
					else
						return "<Tab>" -- Default tab behavior
					end
				end, { buffer = true, expr = true, desc = "Tab Completion in dap-repl" })
				-- 向上浏览补全项
				vim.keymap.set("i", "<S-Tab>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-p>" -- 反向选择补全菜单中的前一个项
					else
						return "<Tab>" -- 默认 Tab 行为
					end
				end, { buffer = true, expr = true, desc = "Reverse Tab Completion in dap-repl" })
				-- 选择补全项
				vim.keymap.set("i", "<CR>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-y>" -- 选择当前补全项（确认补全）
					else
						return "<CR>" -- 默认行为：插入换行符
					end
				end, { buffer = true, expr = true, desc = "Confirm completion or Insert newline in dap-repl" })
			end,
		})

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

		-- Setup

		-- Decides when and how to jump when stopping at a breakpoint
		-- The order matters!
		--
		-- (1) If the line with the breakpoint is visible, don't jump at all
		-- (2) If the buffer is opened in a tab, jump to it instead
		-- (3) Else, create a new tab with the buffer
		--
		-- This avoid unnecessary jumps
		require("dap").defaults.fallback.switchbuf = "usevisible,usetab,newtab"

		-- 退出neovim自动终止调试进程
		vim.api.nvim_create_autocmd("VimLeave", {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}
