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
		name = "🪄 DAP 调试主菜单",
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

	-- 🧭 视图 Hydra
	Hydra({
		name = "🧭 DAP视图模式",
		mode = "n",
		body = "<localleader>d",
		config = {
			color = "teal",
			invoke_on_body = false,
			hint = { type = "window", position = "bottom", show_name = true, wrap = true },
		},
		heads = {
			-- REPL / Eval
			{ "e", "<cmd>DapEval<cr>", { desc = "Eval 表达式" } },
			{
				"r",
				function()
					dap.repl.toggle()
				end,
				{ desc = "切换 REPL 窗口" },
			},

			-- 🔧 作用域 / 堆栈 / 会话 / 线程
			{
				"s",
				function()
					if not sidebar then
						sidebar = widgets.sidebar(widgets.scopes, { width = 40, winblend = 15, signcolumn = "no" })
					end
					sidebar.toggle()
				end,
				{ desc = "查看作用域" },
			},
			{
				"f",
				function()
					widgets.cursor_float(widgets.frames, { border = "rounded" })
				end,
				{ desc = "查看堆栈" },
			},
			{
				"t",
				function()
					widgets.cursor_float(widgets.threads, { border = "rounded" })
				end,
				{ desc = "查看线程" },
			},
			{
				",",
				function()
					widgets.cursor_float(widgets.sessions, { border = "rounded" })
				end,
				{ desc = "查看会话" },
			},

			{ "l", "<cmd>DapShowLog<cr>", { desc = "查看日志" } },
			{
				"L",
				bp.set_debuglog,
				{ desc = "设置日志级别" },
			},
			-- 🟢 dap-view 映射
			{
				"v",
				function()
					dv.toggle(true)
				end,
				{ desc = "切换 dap-view" },
			},
			{ "w", "<cmd>DapViewWatch<cr>", { desc = "添加/删除观察点" } },
			{ "S", "<cmd>DapViewJump scopes<cr>", { desc = "dap-view Scopes" } },
			{ "X", "<cmd>DapViewJump exceptions<cr>", { desc = "dap-view Exceptions" } },
			{ "b", "<cmd>DapViewJump breakpoints<cr>", { desc = "dap-view Breakpoints" } },
			{ "T", "<cmd>DapViewJump threads<cr>", { desc = "dap-view Threads" } },
			{ "R", "<cmd>DapViewJump repl<cr>", { desc = "dap-view REPL" } },
			{ "C", "<cmd>DapViewJump console<cr>", { desc = "dap-view Console" } },

			-- 查看光标下变量 / 自动刷新表达式
			{
				"E",
				function()
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
				end,
				{ desc = "查看光标下表达式并自动刷新" },
			},
			{ "x", "<cmd>DapVirtualTextToggle<cr>", { desc = "切换虚拟文本" } },

			-- ❌ 退出
			{ "<c-c>", nil, { exit = true, desc = "返回主菜单" } },
		},
	})
end

return M
