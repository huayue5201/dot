local M = {}

function M.setup()
	local dap = require("dap")
	local widgets = require("dap.ui.widgets")
	local bp = require("dap.dap_utils")
	local sidebar = nil

	-- ▶ 控制
	vim.keymap.set("n", "<F5>", dap.continue, { desc = "DAP: 继续 / 启动调试" })
	vim.keymap.set("n", "<F4>", function()
		dap.terminate({
			on_done = function()
				dap.repl.close()
				vim.cmd("DapVirtualTextForceRefresh")
			end,
		})
	end, { desc = "DAP: 终止调试" })
	vim.keymap.set("n", "<F6>", dap.pause, { desc = "DAP: 暂停" })

	-- 🪜 步进控制
	vim.keymap.set("n", "<F10>", dap.step_over, { desc = "DAP: 单步跳过" })
	vim.keymap.set("n", "<F9>", dap.step_back, { desc = "DAP: 逆向单步" })
	vim.keymap.set("n", "<F11>", dap.step_into, { desc = "DAP: 单步进入" })
	vim.keymap.set("n", "<F12>", dap.step_out, { desc = "DAP: 单步跳出" })

	-- 🎯 跳转
	vim.keymap.set("n", "<leader>dc", dap.run_to_cursor, { desc = "DAP: 运行到光标" })
	vim.keymap.set("n", "<leader>ds", function()
		vim.ui.input({ prompt = " 󰙎 输入行号: " }, function(input)
			if input then
				local line = tonumber(input)
				if line then
					dap.goto_(line)
				else
					print("无效的行号")
				end
			end
		end)
	end, { desc = "DAP: 跳转到行" })

	-- 💡 断点管理
	vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "DAP: 切换断点" })
	vim.keymap.set("n", "<leader>db", function()
		dap.set_exception_breakpoints()
	end, { desc = "DAP: 设置异常断点" })
	vim.keymap.set("n", "<leader>d?", bp.set_breakpoint, { desc = "DAP: 自定义断点" })
	vim.keymap.set("n", "<leader>dC", function()
		dap.clear_breakpoints()
		require("dap.breakpoint_state").clear_breakpoints()
	end, { desc = "DAP: 清除所有断点" })

	-- 📜 导航
	local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
	-- 创建可重复的跳转函数
	local dap_down_repeat, dap_up_repeat = ts_repeat_move.make_repeatable_move_pair(dap.down, dap.up)
	-- 替换你的按键映射
	vim.keymap.set("n", "<leader>d]", dap_down_repeat, { desc = "DAP: 下一个帧（可重复）" })
	vim.keymap.set("n", "<leader>d[", dap_up_repeat, { desc = "DAP: 上一个帧（可重复）" })
	-- vim.keymap.set("n", "<leader>d{", dap.up, { desc = "DAP: 上一个帧" })
	-- vim.keymap.set("n", "<leader>d}", dap.down, { desc = "DAP: 下一个帧" })

	-- 🔍 评估 / 日志
	vim.keymap.set("n", "<leader>da", function()
		if vim.fn.mode() == "v" then
			local lines = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"))
			dap.repl.open()
			dap.repl.execute(table.concat(lines, "\n"))
		else
			dap.repl.open()
			dap.repl.execute(vim.fn.expand("<cexpr>"))
		end
	end, { desc = "DAP: 评估表达式" })

	-- 查看所有断点
	vim.keymap.set("n", "<leader>dQ", function()
		dap.list_breakpoints()
		vim.cmd("copen")
	end, { desc = "DAP: 查看所有断点" })

	-- vim.keymap.set("n", "<F1>", function()
	-- 	widgets.hover(nil, { border = "rounded" })
	-- end, { desc = "DAP: 查看变量" })

	-- REPL / Eval 相关映射
	vim.keymap.set("n", "<localleader>de", "<cmd>DapEval<cr>", { desc = "DAP: Eval 表达式" })
	vim.keymap.set("n", "<localleader>dr", function()
		dap.repl.toggle()
	end, { desc = "DAP: 切换 REPL 窗口" })

	-- 🔧 作用域 / 堆栈 / 会话 / 线程
	vim.keymap.set("n", "<localleader>ds", function()
		if not sidebar then
			sidebar = widgets.sidebar(widgets.scopes, { width = 40, winblend = 15, signcolumn = "no" })
		end
		sidebar.toggle()
	end, { desc = "DAP: 查看作用域" })

	vim.keymap.set("n", "<localleader>df", function()
		widgets.cursor_float(widgets.frames, { border = "rounded" })
	end, { desc = "DAP: 查看堆栈" })

	vim.keymap.set("n", "<localleader>dt", function()
		widgets.cursor_float(widgets.threads, { border = "rounded" })
	end, { desc = "DAP: 查看线程" })

	vim.keymap.set("n", "<localleader>d,", function()
		widgets.cursor_float(widgets.sessions, { border = "rounded" })
	end, { desc = "DAP: 查看会话" })

	-- 日志相关
	vim.keymap.set("n", "<localleader>dl", "<cmd>DapShowLog<cr>", { desc = "DAP: 查看日志" })
	vim.keymap.set("n", "<localleader>dL", bp.set_debuglog, { desc = "DAP: 设置日志级别" })

	-- 查看光标下变量 / 自动刷新表达式
	vim.keymap.set("n", "<localleader>dE", function()
		widgets.preview(nil, {
			listener = {
				"event_stopped",
				"event_continued",
				"event_terminated",
				"event_initialized",
				"event_thread",
				"event_breakpoint",
			},
		})
	end, { desc = "DAP: 查看光标下表达式并自动刷新" })

	vim.keymap.set("n", "<localleader>dx", "<cmd>DapVirtualTextToggle<cr>", { desc = "DAP: 切换虚拟文本" })
end

return M
