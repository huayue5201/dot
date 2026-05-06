local M = {}

function M.setup()
	local dap = require("dap")
	local dap_ext = require("dap-config.dap-extensions")
	local breakpoint_state = require("dap-config.breakpoint_state")
	local widgets = require("dap.ui.widgets")
	local sidebar = nil

	-- ▶ 控制
	vim.keymap.set("n", "<F5>", dap.continue, { desc = "[D]ap [C]ontinue / [S]tart" })
	vim.keymap.set("n", "<F4>", function()
		dap.terminate({
			on_done = function()
				dap.repl.close()
			end,
		})
		require("dap-view").virtual_text_disable()
		require("dap-config.dap-extensions.ui.virtual_text").clear_all()
	end, { desc = "[D]ap [T]erminate" })
	vim.keymap.set("n", "<F6>", dap.pause, { desc = "[D]ap [P]ause" })

	-- 🪜 步进控制
	vim.keymap.set("n", "<F10>", dap.step_over, { desc = "[D]ap [S]tep [O]ver" })
	vim.keymap.set("n", "<F9>", dap.step_back, { desc = "[D]ap [S]tep [B]ack" })
	vim.keymap.set("n", "<F11>", dap.step_into, { desc = "[D]ap [S]tep [I]nto" })
	vim.keymap.set("n", "<F12>", dap.step_out, { desc = "[D]ap [S]tep [O]ut" })

	-- 🎯 跳转
	vim.keymap.set("n", "<F2>", dap.run_to_cursor, { desc = "[D]ap [R]un to [C]ursor" })
	vim.keymap.set("n", "<F3>", function()
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
	vim.keymap.set("n", "<leader>dx", function()
		dap_ext.delete_breakpoint_at_current_line()
	end, { desc = "[D]ap Delete breakpoint at current line" })

	-- 选择删除断点
	vim.keymap.set("n", "<leader>dX", function()
		dap_ext.toggle_breakpoint_deletion()
	end, { desc = "[D]ap Select breakpoint to delete" })

	-- 查看所有断点（扩展断点）
	vim.keymap.set("n", "<leader>dl", function()
		dap_ext.commands.list_breakpoints()
	end, { desc = "[D]ap List all breakpoints" })

	-- 查询并显示调试器能力
	vim.keymap.set("n", "<localleader>dp", function()
		require("dap-config.dap-capabilities").show()
	end, { desc = "[D]ap Show [C]a[P]abilities" })

	-- 清除所有断点
	vim.keymap.set("n", "<leader>dc", function()
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
			vim.cmd("syntax on")
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
		local keymap_restore = {}
		local original_global_k = nil
		local original_global_bracket_d = {}

		local function save_and_remove_keymap(key, restore_table)
			local global_maps = vim.api.nvim_get_keymap("n")
			for _, map in ipairs(global_maps) do
				if map.lhs == key then
					restore_table[key] = map
					break
				end
			end
			pcall(vim.keymap.del, "n", key)
		end

		local function save_and_remove_buffer_keymaps(key)
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
				for _, keymap in ipairs(keymaps) do
					if keymap.lhs == key then
						keymap.buffer = buf
						table.insert(keymap_restore, keymap)
						pcall(vim.api.nvim_buf_del_keymap, buf, "n", key)
					end
				end
			end
		end

		dap.listeners.after["event_initialized"]["me"] = function()
			vim.g.dap_active = true
			vim.lsp.inlay_hint.enable(false)
			vim.diagnostic.enable(false)
			require("dap-view").virtual_text_enable()

			local global_maps = vim.api.nvim_get_keymap("n")
			for _, map in ipairs(global_maps) do
				if map.lhs == "K" then
					original_global_k = map
					break
				end
			end
			pcall(vim.keymap.del, "n", "K")

			save_and_remove_keymap("[d", original_global_bracket_d)
			save_and_remove_keymap("]d", original_global_bracket_d)

			save_and_remove_buffer_keymaps("K")
			save_and_remove_buffer_keymaps("[d")
			save_and_remove_buffer_keymaps("]d")

			vim.keymap.set("n", "K", function()
				require("dap.ui.widgets").hover()
			end, { silent = true, desc = "[D]ap [H]over" })

			vim.keymap.set("n", "[d", function()
				require("dap").up()
			end, { silent = true, desc = "[D]ap [U]p frame" })

			vim.keymap.set("n", "]d", function()
				require("dap").down()
			end, { silent = true, desc = "[D]ap [D]own frame" })
		end

		dap.listeners.after["event_terminated"]["me"] = function()
			vim.g.dap_active = false
			vim.lsp.inlay_hint.enable(true)
			vim.diagnostic.enable(true)
			require("dap-view").virtual_text_disable()

			for _, keymap in ipairs(keymap_restore) do
				local opts = { silent = keymap.silent == 1 }
				if keymap.expr then
					opts.expr = keymap.expr == 1
				end
				if keymap.nowait then
					opts.nowait = keymap.nowait == 1
				end
				if keymap.desc then
					opts.desc = keymap.desc
				end

				if keymap.rhs then
					pcall(vim.api.nvim_buf_set_keymap, keymap.buffer, keymap.mode, keymap.lhs, keymap.rhs, opts)
				elseif keymap.callback then
					pcall(
						vim.keymap.set,
						keymap.mode,
						keymap.lhs,
						keymap.callback,
						vim.tbl_extend("force", opts, { buffer = keymap.buffer })
					)
				end
			end
			keymap_restore = {}

			pcall(vim.keymap.del, "n", "K")
			pcall(vim.keymap.del, "n", "[d")
			pcall(vim.keymap.del, "n", "]d")

			if original_global_k then
				local opts = { silent = original_global_k.silent == 1 }
				if original_global_k.expr then
					opts.expr = original_global_k.expr == 1
				end
				if original_global_k.nowait then
					opts.nowait = original_global_k.nowait == 1
				end
				if original_global_k.desc then
					opts.desc = original_global_k.desc
				end

				if original_global_k.rhs then
					pcall(vim.keymap.set, "n", "K", original_global_k.rhs, opts)
				elseif original_global_k.callback then
					pcall(vim.keymap.set, "n", "K", original_global_k.callback, opts)
				end
				original_global_k = nil
			end

			for key, mapping in pairs(original_global_bracket_d) do
				if mapping then
					local opts = { silent = mapping.silent == 1 }
					if mapping.expr then
						opts.expr = mapping.expr == 1
					end
					if mapping.nowait then
						opts.nowait = mapping.nowait == 1
					end
					if mapping.desc then
						opts.desc = mapping.desc
					end

					if mapping.rhs then
						pcall(vim.keymap.set, "n", key, mapping.rhs, opts)
					elseif mapping.callback then
						pcall(vim.keymap.set, "n", key, mapping.callback, opts)
					end
				end
			end
			original_global_bracket_d = {}
		end
	end
end

return M
