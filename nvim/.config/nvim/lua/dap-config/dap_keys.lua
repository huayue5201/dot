local M = {}

function M.setup()
	local dap = require("dap")
	local widgets = require("dap.ui.widgets")
	local bp = require("dap-config.dap_utils")
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

	vim.keymap.set("n", "<leader>d?", function()
		bp.set_breakpoint()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, { desc = "DAP: 自定义断点" })

	vim.keymap.set("n", "<leader>dC", function()
		dap.clear_breakpoints()
		require("dap-config.breakpoint_state").clear_breakpoints()
	end, { desc = "DAP: 清除所有断点" })

	vim.keymap.set("n", "<leader>db", function()
		require("dap-config.exception-breakpoints").toggle()
	end, { desc = "DAP: 设置异常断点" })

	vim.keymap.set("n", "[[", dap.up, { desc = "DAP: 上一个帧" })

	vim.keymap.set("n", "]]", dap.down, { desc = "DAP: 下一个帧" })

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

	-- 声明用于存储键位映射的变量（关键修复！）
	local keymap_restore = {}
	local original_global_k = nil
	-- 直接使用全局变量作为标记
	dap.listeners.after["event_initialized"]["me"] = function()
		-- 设置调试状态为激活
		vim.g.dap_active = true -- 替换 Store:set("dap.active", true)

		-- 关闭lsp内嵌提示
		vim.lsp.inlay_hint.enable(false)
		-- 关闭诊断提示
		vim.diagnostic.enable(false)

		-- 保存全局 K 键映射
		local global_maps = vim.api.nvim_get_keymap("n")
		for _, map in ipairs(global_maps) do
			if map.lhs == "K" then
				original_global_k = map
				break
			end
		end

		-- 删除全局 K 键映射
		pcall(vim.keymap.del, "n", "K")

		-- 保存并删除缓冲区本地映射
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
			for _, keymap in ipairs(keymaps) do
				if keymap.lhs == "K" then
					table.insert(keymap_restore, keymap)
					pcall(vim.api.nvim_buf_del_keymap, buf, "n", "K")
				end
			end
		end

		-- 设置新的全局映射
		vim.keymap.set("n", "K", function()
			require("dap.ui.widgets").hover()
		end, { silent = true, desc = "DAP Hover" })
	end

	dap.listeners.after["event_terminated"]["me"] = function()
		-- 设置调试状态为非激活
		vim.g.dap_active = false -- 替换 Store:set("dap.active", false)

		-- 开启lsp内嵌提示
		vim.lsp.inlay_hint.enable(true)
		-- 开启诊断提示
		vim.diagnostic.enable(true)

		-- 恢复缓冲区映射
		for _, keymap in ipairs(keymap_restore) do
			if keymap.rhs then
				pcall(
					vim.api.nvim_buf_set_keymap,
					keymap.buffer,
					keymap.mode,
					keymap.lhs,
					keymap.rhs,
					{ silent = keymap.silent == 1 }
				)
			elseif keymap.callback then
				pcall(
					vim.keymap.set,
					keymap.mode,
					keymap.lhs,
					keymap.callback,
					{ buffer = keymap.buffer, silent = keymap.silent == 1 }
				)
			end
		end
		keymap_restore = {}

		-- 删除调试用的 K 键映射
		pcall(vim.keymap.del, "n", "K")

		-- 恢复原始全局映射
		if original_global_k then
			if original_global_k.rhs then
				pcall(vim.keymap.set, "n", "K", original_global_k.rhs, {
					silent = original_global_k.silent == 1,
					expr = original_global_k.expr == 1,
					nowait = original_global_k.nowait == 1,
				})
			elseif original_global_k.callback then
				pcall(vim.keymap.set, "n", "K", original_global_k.callback, {
					silent = original_global_k.silent == 1,
					expr = original_global_k.expr == 1,
					nowait = original_global_k.nowait == 1,
				})
			end
			original_global_k = nil
		end
	end
end

return M
