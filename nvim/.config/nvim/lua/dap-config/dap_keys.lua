local M = {}

function M.setup()
	local dap = require("dap")
	local dap_ext = require("dap-extensions")
	local breakpoint_state = require("dap-config.breakpoint_state")
	local widgets = require("dap.ui.widgets")
	local sidebar = nil

	-- ▶ 控制
	vim.keymap.set("n", "<leader>dr", dap.continue, { desc = "[D]ap [C]ontinue / [S]tart" })

	-- 运行本项目上次使用的调试配置（无 picker；无记录时回退到选择器）
	vim.keymap.set("n", "<leader>dL", function()
		require("dap-config.persist").continue_last(0)
	end, { desc = "[D]ap [L]ast config" })

	-- 生成项目调试配置模板 .nvim/dap.lua
	vim.keymap.set("n", "<leader>dP", function()
		require("dap-config.project").init(0)
	end, { desc = "[D]ap [P]roject config template" })

	vim.keymap.set("n", "<leader>ds", function()
		dap.terminate({
			on_done = function()
				dap.repl.close()
			end,
		})
		require("dap-view").virtual_text_disable()
		require("dap-extensions.ui.virtual_text").clear_all()
	end, { desc = "[D]ap [T]erminate" })

	vim.keymap.set("n", "<leader>dp", dap.pause, { desc = "[D]ap [P]ause" })

	vim.keymap.set("n", "gji", dap.step_into, { desc = "[D]ap [S]tep [I]nto" })
	vim.keymap.set("n", "gjo", dap.step_out, { desc = "[D]ap [S]tep [O]ut" })
	vim.keymap.set("n", "gjv", dap.step_over, { desc = "[D]ap [S]tep [O]ver" }) -- v 表示越过
	vim.keymap.set("n", "gjc", dap.run_to_cursor, { desc = "[D]ap [R]un to [C]ursor" })

	-- 🎯 跳转
	vim.keymap.set("n", "<leader>dg", function()
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
	end, { desc = "[D]ap [G]oto line" })

	-- 💡 断点管理
	vim.keymap.set("n", "<leader>b", function()
		local bufnr = vim.api.nvim_get_current_buf()
		local line = vim.api.nvim_win_get_cursor(0)[1]

		local bps = dap_ext.list_breakpoints()
		local ext_bp = nil

		for _, bp in ipairs(bps) do
			if bp.config.bufnr == bufnr and bp.config.line == line then
				ext_bp = bp
				break
			end
		end

		if ext_bp then
			-- 有扩展断点，删除它
			local bp_type = ext_bp.type == "column" and "column" or ext_bp.type
			dap_ext.delete_breakpoint_at_current_line()
			vim.notify(string.format("✓ Deleted %s breakpoint at line %d", bp_type, line), "info")
		else
			-- 没有扩展断点，使用原生行断点
			local old_count = #dap_ext.list_breakpoints()
			dap.toggle_breakpoint()
			breakpoint_state.sync_breakpoints()
			local new_count = #dap_ext.list_breakpoints()

			if new_count > old_count then
				vim.notify(string.format("✓ Added line breakpoint at line %d", line), "info")
			else
				vim.notify(string.format("✓ Removed line breakpoint at line %d", line), "info")
			end
		end
	end, { desc = "[D]ap [T]oggle breakpoint (智能切换)" })

	vim.keymap.set(
		"n",
		"<leader>di",
		dap_ext.commands.add_column_breakpoint,
		{ desc = "[D]ap [C]olumn breakpoint (with conditions)" }
	)

	vim.keymap.set(
		"n",
		"<leader>dI",
		dap_ext.commands.quick_column_breakpoint,
		{ desc = "[D]ap [C]olumn breakpoint (quick)" }
	)

	vim.keymap.set("n", "<leader>do", function()
		require("dap-config.conditional_breakpoint").set_breakpoint()
		breakpoint_state.sync_breakpoints()
	end, { desc = "[D]ap [C]onditional breakpoint" })

	-- 函数断点
	vim.keymap.set(
		"n",
		"<leader>df",
		dap_ext.commands.add_function_breakpoint,
		{ desc = "[D]ap [F]unction breakpoint" }
	)

	-- 数据断点
	vim.keymap.set("n", "<leader>dd", dap_ext.commands.add_data_breakpoint, { desc = "[D]ap [D]ata breakpoint" })

	-- 硬件断点
	vim.keymap.set(
		"n",
		"<leader>dh",
		dap_ext.commands.add_hardware_breakpoint,
		{ desc = "[D]ap [H]ardware breakpoint" }
	)

	-- 异常断点
	vim.keymap.set("n", "<leader>de", function()
		require("dap-config.exception-breakpoints").toggle()
	end, { desc = "[D]ap [E]xception breakpoint" })

	-- 启用/禁用断点
	vim.keymap.set("n", "<leader>dt", function()
		dap_ext.commands.toggle_breakpoint_enabled()
	end, { desc = "[D]ap [T]oggle breakpoint enabled/disabled" })

	-- 删除当前行断点
	vim.keymap.set("n", "<leader>cd", function()
		dap_ext.delete_breakpoint_at_current_line()
	end, { desc = "[D]ap Delete breakpoint at current line" })

	-- 选择删除断点
	vim.keymap.set("n", "<leader>cD", function()
		dap_ext.toggle_breakpoint_deletion()
	end, { desc = "[D]ap Select breakpoint to delete" })

	-- 查看所有断点（扩展断点）
	vim.keymap.set("n", "<leader>dla", function()
		dap_ext.commands.list_breakpoints()
	end, { desc = "[D]ap List all breakpoints" })

	-- 查询并显示调试器能力
	vim.keymap.set("n", "<localleader>dp", function()
		require("dap-extensions.capabilities").show()
	end, { desc = "[D]ap Show [C]a[P]abilities" })

	-- 清除所有断点
	vim.keymap.set("n", "<leader>cad", function()
		dap_ext.clear_breakpoints()
		dap.clear_breakpoints()
		breakpoint_state.clear_all_breakpoints()
		print("Cleared all breakpoints")
	end, { desc = "[D]ap [C]lear all breakpoints" })

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
	end, { desc = "[D]ap [E]valuate expression" })

	-- 查看所有断点（quickfix）
	vim.keymap.set("n", "<leader>dq", function()
		dap.list_breakpoints()
		vim.cmd("copen")
	end, { desc = "[D]ap [L]ist breakpoints (quickfix)" })

	-- REPL / Eval 相关映射
	vim.keymap.set("n", "<localleader>de", "<cmd>DapEval<cr>", { desc = "[D]ap [E]val expression" })
	vim.keymap.set("n", "<localleader>dr", function()
		dap.repl.toggle()
	end, { desc = "[D]ap [R]EPL toggle" })

	-- 🔧 作用域 / 堆栈 / 会话 / 线程
	vim.keymap.set("n", "<localleader>ds", function()
		if not sidebar then
			sidebar = widgets.sidebar(widgets.scopes, { width = 40, winblend = 15, signcolumn = "no" })
		end
		sidebar.toggle()
	end, { desc = "[D]ap [S]copes sidebar" })

	vim.keymap.set("n", "<localleader>df", function()
		widgets.cursor_float(widgets.frames, { border = "rounded" })
	end, { desc = "[D]ap [F]rames float" })

	vim.keymap.set("n", "<localleader>dt", function()
		widgets.cursor_float(widgets.threads, { border = "rounded" })
	end, { desc = "[D]ap [T]hreads float" })

	vim.keymap.set("n", "<localleader>d,", function()
		widgets.cursor_float(widgets.sessions, { border = "rounded" })
	end, { desc = "[D]ap [S]essions float" })

	-- 日志相关
	vim.keymap.set("n", "<localleader>dl", "<cmd>DapShowLog<cr>", { desc = "[D]ap [L]og show" })
	vim.keymap.set(
		"n",
		"<localleader>dL",
		require("dap-config.dap_log_keymap").set_debuglog,
		{ desc = "[D]ap [L]og level set" }
	)

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
	end, { desc = "[D]ap [E]xpressions preview" })

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "dap-repl", "dap-view-term", "dap-view", "" },
		group = vim.api.nvim_create_augroup("dapui_keymaps", { clear = true }),
		desc = "Fix and add insert-mode keymaps for dap-repl",
		callback = function()
			vim.opt.signcolumn = "no"
			-- 向下浏览补全项
			vim.keymap.set("i", "<tab>", function()
				if vim.fn.pumvisible() == 1 then
					return "<C-n>"
				else
					return "<Tab>"
				end
			end, { buffer = true, expr = true, desc = "Tab Completion in dap-repl" })
			-- 向上浏览补全项
			vim.keymap.set("i", "<S-Tab>", function()
				if vim.fn.pumvisible() == 1 then
					return "<C-p>"
				else
					return "<Tab>"
				end
			end, { buffer = true, expr = true, desc = "Reverse Tab Completion in dap-repl" })
			-- 选择补全项
			vim.keymap.set({ "i", "n" }, "<CR>", function()
				if vim.fn.pumvisible() == 1 then
					return "<C-y>"
				else
					return "<CR>"
				end
			end, { buffer = true, expr = true, desc = "Confirm completion or Insert newline in dap-repl" })
		end,
	})

	do
		-- 只处理 [d / ]d（frame up/down）的覆盖与恢复。
		-- K 已交给 hover.nvim 的 DAP provider，无需在这里切换。
		-- 用 override_count 保证多会话 / 重启场景下只保存一次原始映射、
		-- 只在最后一个会话结束时恢复，避免误删或把 DAP 映射当作原始映射。
		local frame_keys = { "[d", "]d" }
		local saved_globals = {} -- lhs -> map（全局映射）
		local saved_buffers = {} -- 各 buffer 的局部映射
		local override_count = 0

		local function restore_map(map)
			local opts = {
				silent = map.silent == 1,
				expr = map.expr == 1,
				nowait = map.nowait == 1,
			}
			if map.desc and map.desc ~= "" then
				opts.desc = map.desc
			end
			if map.buffer and map.buffer > 0 then
				opts.buffer = map.buffer
			end
			if map.callback then
				pcall(vim.keymap.set, map.mode, map.lhs, map.callback, opts)
			elseif map.rhs then
				pcall(vim.keymap.set, map.mode, map.lhs, map.rhs, opts)
			end
		end

		local function save_global_keymap(key)
			for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
				if map.lhs == key then
					saved_globals[key] = map
					pcall(vim.keymap.del, "n", key)
					break
				end
			end
		end

		local function save_buffer_keymaps(key)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
					if map.lhs == key then
						table.insert(saved_buffers, map)
						pcall(vim.api.nvim_buf_del_keymap, buf, "n", key)
					end
				end
			end
		end

		local function restore_all()
			for _, map in ipairs(saved_buffers) do
				restore_map(map)
			end
			saved_buffers = {}

			for _, map in pairs(saved_globals) do
				restore_map(map)
			end
			saved_globals = {}
		end

		dap.listeners.after["event_initialized"]["me"] = function()
			vim.g.dap_active = true
			require("core.context").set_debug(true)
			vim.lsp.inlay_hint.enable(false)
			vim.diagnostic.enable(false)
			require("dap-view").virtual_text_enable()

			-- 只在第一次覆盖时保存原始映射，多会话时二次 initialize 不会把 DAP 自己的映射当原始
			override_count = override_count + 1
			if override_count == 1 then
				for _, key in ipairs(frame_keys) do
					save_global_keymap(key)
					save_buffer_keymaps(key)
				end
			end

			vim.keymap.set("n", "[d", function()
				require("dap").up()
			end, { silent = true, desc = "[D]ap [U]p frame" })

			vim.keymap.set("n", "]d", function()
				require("dap").down()
			end, { silent = true, desc = "[D]ap [D]own frame" })
		end

		dap.listeners.after["event_terminated"]["me"] = function()
			vim.g.dap_active = false
			require("core.context").set_debug(false)
			vim.lsp.inlay_hint.enable(true)
			vim.diagnostic.enable(true)
			require("dap-view").virtual_text_disable()

			-- 无配对 initialize 时（适配器未初始化就退出）不删除任何映射
			if override_count == 0 then
				return
			end

			override_count = override_count - 1
			if override_count == 0 then
				for _, key in ipairs(frame_keys) do
					pcall(vim.keymap.del, "n", key)
				end
				restore_all()
			end
		end
	end
end

return M
