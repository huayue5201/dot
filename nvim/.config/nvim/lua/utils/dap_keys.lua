local M = {}

function M.setup()
	local Hydra = require("hydra")
	local dap = require("dap")
	local widgets = require("dap.ui.widgets")
	local dv = require("dap-view")
	local bp = require("utils.dap_utils")
	local sidebar = nil

	-- 🪄 主调试 Hydra
	Hydra({
		name = "🪄DAP模式",
		mode = "n",
		body = "<leader>d",
		config = {
			color = "pink",
			invoke_on_body = false,
			hint = {
				type = "window",
				position = "bottom-right",
				show_name = true,
				float_opts = { border = "rounded" },
			},
		},
		heads = {
			-- ▶ 控制
			{ "c", dap.continue, { desc = "继续 / 启动调试" } },
			{ "s", dap.pause, { desc = "暂停" } },
			{
				"t",
				function()
					dap.terminate({
						on_done = function()
							dap.repl.close()
							dv.close(true)
							vim.cmd("DapVirtualTextForceRefresh")
						end,
					})
				end,
				{ desc = "终止调试" },
			},

			-- 🪜 步进控制
			{ "i", dap.step_into, { desc = "单步进入" } },
			{ "o", dap.step_over, { desc = "单步跳过" } },
			{ "u", dap.step_out, { desc = "单步跳出" } },
			{ "p", dap.step_back, { desc = "逆向单步" } },

			-- 🎯 跳转
			{ "gc", dap.run_to_cursor, { desc = "运行到光标" } },
			{
				"gs",
				function()
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
				end,
				{ desc = "跳转到行" },
			},

			-- 💡 断点管理
			{ "b", dap.toggle_breakpoint, { desc = "切换断点" } },
			{
				"B",
				function()
					dap.set_exception_breakpoints()
				end,
				{ desc = "设置异常断点" },
			},
			{ "?", bp.set_breakpoint, { desc = "自定义断点" } },
			{ "R", dap.clear_breakpoints, { desc = "清除所有断点" } },

			-- 📜 导航
			{ "{", dap.up, { desc = "上一个帧" } },
			{ "}", dap.down, { desc = "下一个帧" } },

			-- 🔍 评估 / 日志
			{
				"a",
				function()
					if vim.fn.mode() == "v" then
						local lines = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"))
						dap.repl.open()
						dap.repl.execute(table.concat(lines, "\n"))
					else
						dap.repl.open()
						dap.repl.execute(vim.fn.expand("<cexpr>"))
					end
				end,
				{ desc = "评估表达式" },
			},

			-- 查看所有断点
			{
				"Q",
				function()
					dap.list_breakpoints()
					vim.cmd("copen")
				end,
				{ desc = "查看所有断点" },
			},
			{
				"K",
				function()
					widgets.hover(nil, { border = "rounded" })
				end,
				{ desc = "查看变量" },
			},

			-- ❌ 退出
			{ "<c-c>", nil, { exit = true, desc = "退出" } },
		},
	})

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

	-- 🟢 dap-view 映射
	vim.keymap.set("n", "<localleader>dv", function()
		dv.toggle(true)
	end, { desc = "DAP: 切换 dap-view" })

	vim.keymap.set("n", "<localleader>dw", "<cmd>DapViewWatch<cr>", { desc = "DAP: 添加/删除观察点" })
	vim.keymap.set("n", "<localleader>dS", "<cmd>DapViewJump scopes<cr>", { desc = "DAP: dap-view Scopes" })
	vim.keymap.set("n", "<localleader>dX", "<cmd>DapViewJump exceptions<cr>", { desc = "DAP: dap-view Exceptions" })
	vim.keymap.set("n", "<localleader>db", "<cmd>DapViewJump breakpoints<cr>", { desc = "DAP: dap-view Breakpoints" })
	vim.keymap.set("n", "<localleader>dT", "<cmd>DapViewJump threads<cr>", { desc = "DAP: dap-view Threads" })
	vim.keymap.set("n", "<localleader>dR", "<cmd>DapViewJump repl<cr>", { desc = "DAP: dap-view REPL" })
	vim.keymap.set("n", "<localleader>dC", "<cmd>DapViewJump console<cr>", { desc = "DAP: dap-view Console" })

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
