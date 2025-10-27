-- https://github.com/mfussenegger/nvim-dap
-- NOTE : https://github.com/Jorenar/nvim-dap-disasm 提供反汇编（disassembly)

return {
	"mfussenegger/nvim-dap",
	event = "VeryLazy",
	dependencies = {
		-- https://github.com/igorlfs/nvim-dap-view
		"igorlfs/nvim-dap-view",
		-- https://github.com/theHamsta/nvim-dap-virtual-text
		"theHamsta/nvim-dap-virtual-text",
		"nvimtools/hydra.nvim", -- 添加 hydra 依赖
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

		local Hydra = require("hydra")

		-- 主调试 Hydra
		Hydra({
			name = "DAP 调试",
			mode = "n",
			body = "<localleader>d",
			config = {
				color = "pink",
				invoke_on_body = false,
				hint = {
					type = "window",
					position = "bottom",
					show_name = true,
				},
				on_enter = function()
					vim.notify("🚀 进入调试模式", vim.log.levels.INFO)
				end,
				on_exit = function()
					vim.notify("退出调试模式", vim.log.levels.INFO)
				end,
			},
			heads = {
				-- 基础控制
				{ "s", dap.pause, { desc = "暂停线程" } },

				-- 步进控制
				{ "o", dap.step_over, { desc = "单步跳过" } },
				{ "i", dap.step_into, { desc = "单步进入" } },
				{ "u", dap.step_out, { desc = "单步跳出" } },
				{ "b", dap.step_back, { desc = "逆向单步" } },
				{ "g", dap.run_to_cursor, { desc = "运行到光标" } },
				{ "r", dap.reverse_continue, { desc = "逆向继续" } },

				-- 断点管理
				{ "b", dap.toggle_breakpoint, { desc = "切换断点" } },
				{
					"B",
					function()
						dap.set_exception_breakpoints()
					end,
					{ desc = "异常断点" },
				},

				-- 会话管理
				{ "l", dap.run_last, { desc = "运行上次帧" } },
				{ "f", dap.restart_frame, { desc = "重启当前帧" } },

				-- 导航
				{ "[", dap.up, { desc = "上一个断点" } },
				{ "]", dap.down, { desc = "下一个断点" } },
				{ "G", dap.focus_frame, { desc = "跳转到当前帧" } },

				-- 退出
				{ "q", nil, { exit = true, desc = "退出" } },
				{ "<Esc>", nil, { exit = true, desc = false } },
			},
		})

		vim.keymap.set("n", "<leader>dc", dap.continue, { silent = true, desc = "继续/启动调试" })

		vim.keymap.set("n", "<leader>dd", function()
			dap.terminate({
				on_done = function()
					dap.repl.close()
					require("dap-view").close(true)
					vim.cmd("DapVirtualTextForceRefresh")
				end,
			})
		end, { silent = true, desc = "终止调试" })

		-- vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { silent = true, desc = "设置/取消断点" })

		-- vim.keymap.set("n", "<leader>B", function()
		-- 	dap.set_exception_breakpoints()
		-- end, { silent = true, desc = "异常断点" })
		local bp = require("utils.dap_utils")
		vim.keymap.set("n", "<leader>dib", bp.set_breakpoint, { desc = "设置断点" })

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

		vim.keymap.set("n", "<leader>dar", function()
			dap.repl.open()
			dap.repl.execute(vim.fn.expand("<cexpr>"))
		end, { desc = "评估选中表达式" })

		vim.keymap.set("v", "<leader>dar", function()
			-- getregion requires nvim 0.10
			local lines = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"))
			dap.repl.open()
			dap.repl.execute(table.concat(lines, "\n"))
		end, { desc = "评估选中表达式" })
		-- 扩展 REPL 命令
		local repl = require("dap.repl")
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

		vim.keymap.set("n", "<leader>de", "<cmd>DapEval<cr>", { silent = true, desc = "打开 Eval" })

		vim.keymap.set("n", "<leader>dll", "<cmd>DapShowLog<cr>", { desc = "查看调试日志" })

		vim.keymap.set("n", "<leader>dil", function()
			local levels = {
				"TRACE", -- 追踪，最详细的日志信息
				"DEBUG", -- 调试信息
				"INFO", -- 一般信息，默认级别
				"WARN", -- 警告信息
				"ERROR", -- 错误信息
			}
			vim.ui.select(levels, {
				prompt = "选择 DAP 日志级别:",
				format_item = function(item)
					local desc = {
						TRACE = "追踪，最详细的日志信息",
						DEBUG = "调试信息",
						INFO = "一般信息，默认级别",
						WARN = "警告信息",
						ERROR = "错误信息",
					}
					return item .. " — " .. desc[item]
				end,
			}, function(choice)
				if choice then
					require("dap").set_log_level(choice)
					print("DAP 日志级别设置为: " .. choice)
				else
					print("未选择日志级别，操作取消")
				end
			end)
		end, { desc = "设置 DAP 日志级别" })

		vim.keymap.set("n", "<leader>dlq", function()
			dap.list_breakpoints()
			vim.cmd("copen")
			-- vim.cmd("wincmd p") -- 或者用 "wincmd J" 把 quickfix 拉到底部
		end, { desc = "查看所有断点" })

		local widgets = require("dap.ui.widgets")

		vim.keymap.set("n", "<leader>dlk", function()
			widgets.hover(nil, { border = "rounded" })
		end, { silent = true, desc = "查看变量" })

		vim.keymap.set("n", "<leader>dle", function()
			widgets.preview(nil, {
				listener = {
					"event_stopped", -- 停下时更新
					"event_continued", -- 继续时可清空或更新
					"event_terminated", -- 会话结束时清理
					"event_initialized", -- 可选，在调试会话开始时刷新
					"event_thread", -- 有时可以响应线程状态变化
					"event_breakpoint", -- 添加或命中断点
				},
			})
		end, { desc = "查看光标下的表达式并自动刷新" })

		local sidebar = nil
		vim.keymap.set("n", "<leader>dlc", function()
			if not sidebar then
				sidebar = widgets.sidebar(widgets.scopes, { width = 40, winblend = 15, signcolumn = "no" })
			end
			sidebar.toggle()
		end, { desc = "查看作用域" })

		vim.keymap.set("n", "<leader>dls", function()
			widgets.cursor_float(widgets.sessions, { border = "rounded" })
		end, { desc = "查看调试会话" })

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
				-- vim.cmd("runtime! syntax/rust.vim") -- 手动加载 Rust 的语法文件
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

		local module_cache = {}
		local function load_modules_from_dir(dir)
			if not module_cache[dir] then
				local path = vim.fn.stdpath("config") .. "/" .. dir
				module_cache[dir] = vim.fn.globpath(path, "*.lua", false, true)
			end
			for _, file in ipairs(module_cache[dir]) do
				-- 用 sub 来提取模块名
				local module_name = file:sub(#vim.fn.stdpath("config") + 2, -5):gsub("/", ".")
				-- 修正模块名称去掉 "lua." 前缀
				module_name = module_name:sub(5) -- 移除前4个字符，即 "lua."
				-- 尝试加载模块
				local ok, mod_or_err = pcall(require, module_name)
				if not ok then
					print("Failed to load module '" .. module_name .. "': " .. mod_or_err)
					vim.notify("Failed to load module '" .. module_name .. "': " .. mod_or_err, vim.log.levels.ERROR)
				elseif mod_or_err.setup then
					mod_or_err.setup(dap)
				end
			end
		end
		-- 加载模块
		load_modules_from_dir("lua/dap")

		vim.api.nvim_create_autocmd({ "VimLeave" }, {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}

-- TODO:备选映射方式
-- vim.keymap.set("n", "<leader>drb", dap.clear_breakpoints, { silent = true, desc = "清除所有断点" })

-- vim.keymap.set("n", "<leader>dnl", dap.run_last, { silent = true, desc = "运行上次会话" })

-- vim.keymap.set("n", "<leader>dno", dap.step_over, { silent = true, desc = "单步跳过" })

-- vim.keymap.set("n", "<leader>dni", dap.step_out, { silent = true, desc = "单步进入" })

-- vim.keymap.set("n", "<leader>dnu", dap.step_out, { silent = true, desc = "单步跳出" })

-- vim.keymap.set("n", "<leader>dnb", dap.step_back, { silent = true, desc = "逆向单步" })

-- vim.keymap.set("n", "<leader>dnc", dap.run_to_cursor, { silent = true, desc = "运行到光标位置" })

-- vim.keymap.set("n", "<leader>dnr", dap.reverse_continue, { silent = true, desc = "逆向继续" })

-- vim.keymap.set("n", "<leader>dnf", dap.restart_frame, { silent = true, desc = "重启当前帧" })

-- vim.keymap.set("n", "<leader>ds", dap.pause, { silent = true, desc = "暂停线程" })

-- vim.keymap.set("n", "<leader>d[", dap.up, { silent = true, desc = "上一个断点" })

-- vim.keymap.set("n", "<leader>d]", dap.down, { silent = true, desc = "下一个断点" })

-- vim.keymap.set("n", "<leader>dgg", dap.focus_frame, { silent = true, desc = "跳转到当前帧" })
