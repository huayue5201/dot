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
		vim.cmd([[au FileType dap-repl lua require('dap.ext.autocompl').attach()]])

		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF0000" })
		vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#FFDAB9" })
		vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#8B8B7A" })
		vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#00BFFF" })
		vim.api.nvim_set_hl(0, "YellowCursor", { fg = "#FFCC00", bg = "" })
		vim.api.nvim_set_hl(0, "YellowBack", { bg = "#4C4C19" })
		local signs = {
			DapBreakpoint = { text = "󰯯 ", texthl = "DapBreakpoint" }, -- 断点
			DapBreakpointCondition = { text = "󰯲 ", texthl = "DapBreakpointCondition" }, -- 条件断点
			DapBreakpointRejected = { text = " ", texthl = "DapBreakpointRejected" }, -- 拒绝断点
			DapLogPoint = { text = "󰰍 ", texthl = "DapLogPoint" }, -- 日志点
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

		local module_cache = {}
		local function load_modules_from_dir(dir)
			if not module_cache[dir] then
				local path = vim.fn.stdpath("config") .. "/" .. dir
				module_cache[dir] = vim.fn.globpath(path, "*.lua", false, true)
			end
			for _, file in ipairs(module_cache[dir]) do
				local module_name =
					file:match("(.+).lua$"):gsub(vim.pesc(vim.fn.stdpath("config") .. "/"), ""):gsub("/", ".")
				local ok, mod = pcall(require, module_name)
				if ok then
					if mod.setup then
						mod.setup(dap)
					end
				else
				end
			end
		end
		-- 加载模块
		load_modules_from_dir("lua/dap/adapters")
		load_modules_from_dir("lua/dap/configs")
		load_modules_from_dir("lua/dap/listeners")

		--  nvim-dap配置
		local dap_defaults = {
			switchbuf = "usevisible,usetab,newtab", -- 在调试时使用打开的缓冲区
			terminal_win_cmd = "belowright new", -- 设置终端窗口在底部打开
			focus_terminal = true, -- 打开终端时将焦点切换到终端
			autostart = "nluarepl", -- 自动启动 Lua REPL
			console = "integratedTerminal", -- 控制台设置
			stepping_granularity = "statement", -- `line` or `instructions`
			external_terminal = {
				command = "/usr/bin/alacritty", -- 外部终端的命令路径
				args = { "-e" }, -- 外部终端的参数
			},
		}
		-- 将配置应用到 dap.defaults.fallback
		for key, value in pairs(dap_defaults) do
			dap.defaults.fallback[key] = value
		end

		-- 定义 _dap_continue 函数来调用 dap.continue
		_G._dap_continue = function()
			dap.continue() -- 调用 dap.continue 方法
		end
		vim.keymap.set("n", "<leader>dc", function()
			vim.o.operatorfunc = "v:lua._dap_continue" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "继续/启动调试" })

		vim.keymap.set("n", "<leader>rd", function()
			dap.terminate({
				on_done = function()
					require("dap").repl.close()
					require("dap-view").close(true)
					vim.cmd("DapVirtualTextForceRefresh")
				end,
			})
		end, { silent = true, desc = "终止调试" })

		_G._toggle_breakpoint = function()
			dap.toggle_breakpoint()
		end
		vim.keymap.set("n", "<leader>b", function()
			vim.o.operatorfunc = "v:lua._toggle_breakpoint" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "设置/取消断点" })

		vim.keymap.set("n", "<leader>B", function()
			require("dap").set_exception_breakpoints()
		end, { silent = true, desc = "异常断点" })

		vim.keymap.set("n", "<leader>dib", function()
			vim.ui.select({ "条件断点", "命中次数", "日志点", "多条件断点" }, {
				prompt = "选择断点类型:",
			}, function(choice)
				if choice == "条件断点" then
					vim.ui.input({ prompt = "󰌓 输入条件: " }, function(condition)
						-- 自动将输入转换为字符串
						local str_condition = tostring(condition)
						if str_condition ~= "" then
							dap.toggle_breakpoint(str_condition) -- 设置条件断点
						else
							vim.notify("条件不能为空！", vim.log.levels.ERROR)
						end
					end)
				elseif choice == "命中次数" then
					vim.ui.input({ prompt = "󰌓 输入次数: " }, function(hit_count)
						-- 自动将输入转换为数字并检查
						local str_hit_count = tonumber(hit_count)
						if str_hit_count then
							dap.toggle_breakpoint(nil, str_hit_count) -- 设置命中次数断点
						else
							vim.notify("无效输入次数！请输入有效的数字。", vim.log.levels.ERROR)
						end
					end)
				elseif choice == "日志点" then
					vim.ui.input({ prompt = "󰌓 输入日志内容: " }, function(message)
						-- 自动将输入转换为字符串
						local str_message = tostring(message)
						if str_message ~= "" then
							dap.toggle_breakpoint(nil, nil, str_message) -- 设置日志点
						else
							vim.notify("日志内容不能为空！", vim.log.levels.ERROR)
						end
					end)
				elseif choice == "多条件断点" then
					vim.ui.input(
						{ prompt = "󰌓 输入多条件（逗号分隔，支持转义字符）: " },
						function(input)
							-- 处理输入，按逗号分割，并确保正确识别 nil
							local conditions = {}
							if input then
								-- 移除两端空白字符
								input = input:match("^%s*(.-)%s*$")
								-- 处理转义符号：替换转义的逗号（\）为特殊字符标记
								input = input:gsub("\\,", "COMMA")
								-- 通过逗号分割输入
								for condition in string.gmatch(input, "([^,]+)") do
									-- 恢复转义的逗号
									condition = condition:gsub("COMMA", ",")
									table.insert(conditions, condition:match("^%s*(.-)%s*$")) -- 去除空白字符
								end
								-- 解析为3个参数：条件，命中次数，日志消息
								local condition = conditions[1]
								local hit_count = conditions[2]
								local log_message = conditions[3]

								-- 特别处理 nil 部分，确保 nil 作为一个有效的参数
								if condition == "nil" then
									condition = nil
								end
								if hit_count == "nil" then
									hit_count = nil
								end
								if log_message == "nil" then
									log_message = nil
								end
								-- 检查命中次数参数是否有效
								if hit_count ~= nil and not tonumber(hit_count) then
									vim.notify("命中次数只能是数字或nil！", vim.log.levels.ERROR)
									return
								end
								-- 调用 dap.toggle_breakpoint，根据参数数量设置不同类型的断点
								dap.toggle_breakpoint(condition, hit_count, log_message)
							end
						end
					)
				end
			end)
		end, { desc = "设置断点" })

		vim.keymap.set("n", "<leader>rb", dap.clear_breakpoints, { silent = true, desc = "清除所有断点" })

		vim.keymap.set("n", "<leader>drl", dap.run_last, { silent = true, desc = "运行上次会话" })

		_G._dap_step_over = function()
			dap.step_over()
		end
		vim.keymap.set("n", "<leader>dro", function()
			vim.o.operatorfunc = "v:lua._dap_step_over" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "单步跳过" })

		_G._dap_step_into = function()
			dap.step_out()
		end
		vim.keymap.set("n", "<leader>dri", function()
			vim.o.operatorfunc = "v:lua._dap_step_into" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "单步进入" })

		_G._dap_step_out = function()
			dap.step_out()
		end
		vim.keymap.set("n", "<leader>dru", function()
			vim.o.operatorfunc = "v:lua._dap_step_out" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "单步跳出" })

		_G._dap_step_back = function()
			dap.step_back()
		end
		vim.keymap.set("n", "<leader>drb", function()
			vim.o.operatorfunc = "v:lua._dap_step_back" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "逆向单步" })

		_G._dap_run_to_cursor = function()
			dap.run_to_cursor()
		end
		vim.keymap.set("n", "<leader>drc", function()
			vim.o.operatorfunc = "v:lua._dap_run_to_cursor" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "运行到光标位置" })

		vim.keymap.set("n", "<leader>drr", dap.reverse_continue, { silent = true, desc = "逆向继续" })

		vim.keymap.set("n", "<leader>drf", dap.restart_frame, { silent = true, desc = "重启当前帧" })

		vim.keymap.set("n", "<leader>dd", dap.pause, { silent = true, desc = "暂停线程" })

		_G._dap_up = function()
			dap.up()
		end
		vim.keymap.set("n", "<leader>dgk", function()
			vim.o.operatorfunc = "v:lua._dap_up" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "上一个断点" })

		_G._dap_down = function()
			dap.down()
		end
		vim.keymap.set("n", "<leader>dgj", function()
			vim.o.operatorfunc = "v:lua._dap_down" -- 使用一个正确的函数名
			vim.cmd.normal("g@l") -- 执行操作符
		end, { silent = true, desc = "下一个断点" })

		vim.keymap.set("n", "<leader>dgg", dap.focus_frame, { silent = true, desc = "跳转到当前帧" })

		vim.keymap.set("n", "<leader>dgn", function()
			vim.ui.input({ prompt = " 󰙎 输入行号: " }, function(input)
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

		vim.keymap.set("n", "<leader>dlr", function()
			dap.repl.toggle()
		end, { silent = true, desc = "切换 REPL" })

		vim.keymap.set("n", "<leader>de", "<cmd>DapEval<cr>", { silent = true, desc = "打开 Eval" })

		vim.keymap.set("n", "<leader>dlq", function()
			dap.list_breakpoints()
			vim.cmd("copen")
			-- vim.cmd("wincmd p") -- 或者用 "wincmd J" 把 quickfix 拉到底部
		end, { desc = "查看所有断点" })

		local widgets = require("dap.ui.widgets")

		-- _G._dap_hover = function()
		-- 	widgets.hover(nil, { border = "rounded" })
		-- end
		-- vim.keymap.set("n", "<leader>dlk", function()
		-- 	vim.o.operatorfunc = "v:lua._dap_hover" -- 使用一个正确的函数名
		-- 	vim.cmd.normal("g@l") -- 执行操作符
		-- end, { silent = true, desc = "查看变量" })

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

		vim.keymap.set("n", "<leader>dlp", function()
			widgets.preview("some_variable", { listener = { "changed", "cursor_moved" } })
		end, { desc = "查看达式值" })

		local sidebar = nil
		vim.keymap.set("n", "<leader>dlc", function()
			if not sidebar then
				sidebar = widgets.sidebar(widgets.scopes, { width = 35, winblend = 15, signcolumn = "no" })
			end
			sidebar.toggle()
		end, { desc = "查看作用域" })

		vim.keymap.set("n", "<leader>dls", function()
			widgets.cursor_float(widgets.sessions, { border = "rounded" })
		end, { desc = "查看调试会话" })

		vim.keymap.set("n", "<leader>dle", function()
			local winopts = {
				width = 60, -- 窗口宽度
				height = 6, -- 窗口高度
				border = "double", -- 双线边框
			}
			widgets.centered_float(widgets.expression, winopts)
		end, { desc = "查看表达式值" })

		vim.keymap.set("n", "<leader>dlt", function()
			widgets.cursor_float(widgets.threads, { border = "rounded" })
		end, { desc = "查看线程" })

		vim.keymap.set("n", "<leader>dlf", function()
			widgets.cursor_float(widgets.frames, { border = "rounded" })
		end, { desc = "查看堆栈" })

		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "dap-repl", "dap-view-term", "dap-view" },
			group = vim.api.nvim_create_augroup("dapui_keymaps", { clear = true }),
			desc = "Fix and add insert-mode keymaps for dap-repl",
			callback = function()
				vim.cmd("syntax on") -- 启用语法高亮（保险）
				vim.cmd("runtime! syntax/rust.vim") -- 手动加载 Rust 的语法文件
				vim.opt.signcolumn = "no" -- 禁用标志列
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

		-- 退出neovim自动终止调试进程
		vim.api.nvim_create_autocmd("VimLeave", {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}
