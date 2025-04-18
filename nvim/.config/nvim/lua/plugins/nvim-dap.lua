-- https://github.com/mfussenegger/nvim-dap
-- TODO: https://github.com/mfussenegger/nvim-dap/issues/1388

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
			DapBreakpointRejected = { text = "🌀", texthl = "DapBreakpointRejected" }, -- 拒绝断点
			DapLogPoint = { text = "🔵", texthl = "DapLogPoint" }, -- 日志点
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
		-- require("utils.debug-file-manager") -- 调试文件标记模块
		local dap = require("dap")

		-- 加载模块化配置
		local modules = {
			require("dap.adapters.probe_rs"),
			require("dap.configs.rust"),
			require("dap.listeners.probe_rs"),
		}

		for _, mod in ipairs(modules) do
			mod.setup(dap)
		end

		--  nvim-dap配置
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

		vim.keymap.set("n", "<leader>rd", function()
			dap.terminate({
				on_done = function()
					require("dap").repl.close()
					require("dap-view").close(true)
					vim.cmd("DapVirtualTextForceRefresh")
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

		vim.g.repeatable_map("n", "<leader>dgk", dap.up, { silent = true, desc = "上一个断点" })

		vim.g.repeatable_map("n", "<leader>dgj", dap.down, { silent = true, desc = "下一个断点" })

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

		vim.keymap.set("n", "<leader>dlq", function()
			dap.list_breakpoints()
			vim.cmd("copen")
			-- vim.cmd("wincmd p") -- 或者用 "wincmd J" 把 quickfix 拉到底部
		end, { desc = "查看所有断点" })

		local widgets = require("dap.ui.widgets")

		vim.keymap.set("n", "<leader>dlk", function()
			widgets.hover(nil, { border = "rounded" })
		end, { desc = "查看变量" })

		-- local sidebar = nil
		-- vim.keymap.set("n", "<leader>dlc", function()
		-- 	if not sidebar then
		-- 		sidebar = widgets.sidebar(widgets.scopes, { border = "rounded" ，width = 40})
		-- 	end
		-- 	sidebar.toggle()
		-- end, { desc = "查看作用域" })

		vim.keymap.set("n", "<leader>dlc", function()
			widgets.centered_float(widgets.scopes, { border = "rounded" })
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

		-- vim.keymap.set("n", "<leader>du", dap.run, { silent = true, desc = "启动新调试会话" })

		local history = {}
		vim.keymap.set("n", "<leader>du", function()
			local filetype = vim.bo.filetype
			local program = vim.fn.expand("%")

			local adapter_map = {
				rust = { "probe-rs-debug", "cortex-debug" },
				c = "cortex-debug",
				cpp = "cortex-debug",
			}

			local function resolve_adapter(callback)
				local entry = adapter_map[filetype]
				if type(entry) == "table" then
					if #entry == 1 then
						callback(entry[1])
					else
						vim.ui.select(entry, { prompt = "请选择调试器适配器：" }, function(choice)
							if choice then
								callback(choice)
							end
						end)
					end
				else
					callback(entry or filetype)
				end
			end

			vim.ui.select({ "手动输入参数", "从历史记录选择" }, {
				prompt = "选择运行方式：",
			}, function(choice)
				if choice == "手动输入参数" then
					vim.ui.input({ prompt = "输入参数(空格分隔)：" }, function(input)
						if not input then
							return
						end
						local args = vim.split(input, "%s+")

						resolve_adapter(function(adapter)
							local approval = vim.fn.confirm(
								("将使用以下配置运行程序：\n\n    [%s] %s %s\n\n是否确认？"):format(
									adapter,
									program,
									input
								),
								"&Yes\n&No",
								1
							)

							if approval ~= 1 then
								return
							end

							dap.run({
								type = adapter,
								request = "launch",
								name = "Launch with args",
								program = program,
								args = args,
								cwd = vim.fn.getcwd(),
								stopOnEntry = false,
							})

							table.insert(history, {
								filetype = filetype,
								program = program,
								adapter = adapter,
								args = args,
							})
							if #history > 20 then
								table.remove(history, 1)
							end
						end)
					end)
				elseif choice == "从历史记录选择" then
					if #history == 0 then
						vim.notify("暂无历史记录", vim.log.levels.INFO)
						return
					end

					local entries = {}
					for i, item in ipairs(history) do
						table.insert(
							entries,
							string.format(
								"[%d] [%s] %s %s",
								i,
								item.adapter,
								item.program,
								table.concat(item.args, " ")
							)
						)
					end

					vim.ui.select(entries, { prompt = "选择历史记录运行：" }, function(_, idx)
						local entry = history[idx]
						if not entry then
							return
						end
						dap.run({
							type = entry.adapter,
							request = "launch",
							name = "Re-run from history",
							program = entry.program,
							args = entry.args,
							cwd = vim.fn.getcwd(),
							stopOnEntry = false,
						})
					end)
				end
			end)
		end, { desc = "运行当前文件（带参数/历史）" })

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
