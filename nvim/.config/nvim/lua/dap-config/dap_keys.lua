local M = {}

function M.setup()
	local dap = require("dap")
	local dap_ext = require("dap-config.dap-extensions")
	local widgets = require("dap.ui.widgets")
	local sidebar = nil

	-- ▶ 控制
	vim.keymap.set("n", "<F5>", dap.continue, { desc = "DAP: 继续 / 启动调试" })
	vim.keymap.set("n", "<F4>", function()
		dap.terminate({
			on_done = function()
				dap.repl.close()
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
	vim.keymap.set("n", "<F2>", dap.run_to_cursor, { desc = "DAP: 运行到光标" })
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
	end, { desc = "DAP: 跳转到行" })

	-- 💡 断点管理

	vim.keymap.set("n", "<leader>b", function()
		dap.toggle_breakpoint()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, { desc = "DAP: 切换断点" })

	vim.keymap.set("n", "<leader>do", function()
		require("dap-config.conditional_breakpoint").set_breakpoint()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, { desc = "DAP: 自定义断点" })

	-- 添加断点管理快捷键（统一使用 UI）
	vim.keymap.set(
		"n",
		"<leader>df",
		dap_ext.commands.add_function_breakpoint,
		{ desc = "Add function breakpoint with conditions" }
	)

	vim.keymap.set(
		"n",
		"<leader>dd",
		dap_ext.commands.add_data_breakpoint,
		{ desc = "Add data breakpoint with conditions" }
	)

	vim.keymap.set("n", "<leader>dl", function()
		local bps = dap_ext.list_breakpoints()
		if #bps == 0 then
			print("No breakpoints")
			return
		end
		print("Breakpoints:")
		for _, bp in ipairs(bps) do
			local info = string.format("  [%s] %s", bp.status, bp.type)
			if bp.type == "function" then
				info = info .. ": " .. (bp.config.function_name or bp.function_name)
				if bp.config.condition then
					info = info .. " (if: " .. bp.config.condition .. ")"
				end
			elseif bp.type == "data" then
				info = info .. ": " .. (bp.config.expression or bp.expression)
			end
			print(info)
		end
	end, { desc = "List breakpoints" })

	vim.keymap.set("n", "<leader>dc", function()
		dap_ext.clear_breakpoints()
		dap.clear_breakpoints()
		require("dap-config.breakpoint_state").clear_breakpoints()
		print("Cleared all breakpoints")
	end, { desc = "Clear all breakpoints" })

	vim.keymap.set("n", "<leader>db", function()
		require("dap-config.exception-breakpoints").toggle()
	end, { desc = "DAP: 设置异常断点" })

	-- vim.keymap.set("n", "<leader>d[", dap.up, { desc = "DAP: 上一个帧" })
	-- vim.keymap.set("n", "<leader>d]", dap.down, { desc = "DAP: 下一个帧" })

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
	vim.keymap.set("n", "<leader>dq", function()
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
	vim.keymap.set(
		"n",
		"<localleader>dL",
		require("dap-config.dap_log_keymap").set_debuglog,
		{ desc = "DAP: 设置日志级别" }
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
	end, { desc = "DAP: 查看光标下表达式并自动刷新" })

	vim.keymap.set("n", "<localleader>dx", "<cmd>DapVirtualTextToggle<cr>", { desc = "DAP: 切换虚拟文本" })

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "dap-repl", "dap-view-term", "dap-view", "" },
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
			vim.keymap.set({ "i", "n" }, "<CR>", function()
				if vim.fn.pumvisible() == 1 then
					return "<C-y>" -- 选择当前补全项（确认补全）
				else
					return "<CR>" -- 默认行为：插入换行符
				end
			end, { buffer = true, expr = true, desc = "Confirm completion or Insert newline in dap-repl" })
		end,
	})

	do
		local keymap_restore = {}
		local original_global_k = nil
		local original_global_bracket_d = {} -- 保存 [d 和 ]d 的全局映射

		-- 保存并删除指定的键映射
		local function save_and_remove_keymap(key, maps_table, restore_table)
			local global_maps = vim.api.nvim_get_keymap("n")
			for _, map in ipairs(global_maps) do
				if map.lhs == key then
					restore_table[key] = map
					break
				end
			end
			pcall(vim.keymap.del, "n", key)
		end

		-- 保存并删除缓冲区中的指定键映射
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

			-- 保存并删除 K 键映射
			local global_maps = vim.api.nvim_get_keymap("n")
			for _, map in ipairs(global_maps) do
				if map.lhs == "K" then
					original_global_k = map
					break
				end
			end
			pcall(vim.keymap.del, "n", "K")

			-- 保存并删除 [d 和 ]d 的全局映射
			save_and_remove_keymap("[d", "[d", original_global_bracket_d)
			save_and_remove_keymap("]d", "]d", original_global_bracket_d)

			-- 保存并删除缓冲区中的 K, [d, ]d 映射
			save_and_remove_buffer_keymaps("K")
			save_and_remove_buffer_keymaps("[d")
			save_and_remove_buffer_keymaps("]d")

			-- 设置 DAP 的临时映射
			vim.keymap.set("n", "K", function()
				require("dap.ui.widgets").hover()
			end, { silent = true, desc = "DAP Hover" })

			vim.keymap.set("n", "[d", function()
				require("dap").up()
			end, { silent = true, desc = "DAP: 上一个帧" })

			vim.keymap.set("n", "]d", function()
				require("dap").down()
			end, { silent = true, desc = "DAP: 下一个帧" })
		end

		dap.listeners.after["event_terminated"]["me"] = function()
			vim.g.dap_active = false
			vim.lsp.inlay_hint.enable(true)
			vim.diagnostic.enable(true)

			-- 恢复缓冲区映射
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

			-- 删除临时映射
			pcall(vim.keymap.del, "n", "K")
			pcall(vim.keymap.del, "n", "[d")
			pcall(vim.keymap.del, "n", "]d")

			-- 恢复原始全局映射
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

			-- 恢复 [d 和 ]d 的全局映射
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
