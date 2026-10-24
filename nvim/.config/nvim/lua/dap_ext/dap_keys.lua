-- lua/dap_ext/dap_keys.lua
-- DAP 键位 + 键位直接触发的一次性动作（条件断点面板、日志级别选择）
--
-- dap_ext 目录分工：
--   dap_keys.lua           键位与其直接触发的交互（本文件）
--   breakpoint_state.lua   断点状态同步（原生断点 + dap-extensions 自定义断点）
--   project.lua            项目类型判定 + <root>/.nvim/dap.lua 本地配置
--   persist.lua            项目级「上次运行配置」记忆
--   debug-file-picker.lua  无配置时的文件/函数选择器
--   adapters/              各调试适配器的 dap.adapters / dap.configurations
local M = {}

-- 断点设置后同步扩展断点状态（原生断点的变更不会自动通知 dap-extensions）
local function sync_after_set()
	vim.defer_fn(function()
		require("dap_ext.breakpoint_state").sync_breakpoints()
	end, 10)
end

--- 条件/命中次数/日志断点输入面板（dap-extensions popup）
local function set_conditional_breakpoint()
	local dap = require("dap")
	local popup = require("dap-extensions.ui.popup")
	popup.open({
		fields = {
			{ key = "condition", label = "条件(可选)" },
			{ key = "hit", label = "命中次数(可选)" },
			{ key = "log", label = "日志消息(可选)" },
		},
		on_submit = function(values)
			local condition = values.condition ~= "" and values.condition or nil
			local hit = values.hit ~= "" and tonumber(values.hit) or nil
			local log = values.log ~= "" and values.log or nil

			if values.hit ~= "" and not tonumber(values.hit) then
				vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
				return
			end

			dap.toggle_breakpoint(condition, hit, log)
			print(
				("✔️ 断点已设置：条件=%s 次数=%s 日志=%s"):format(
					condition or "无",
					hit or "无",
					log or "无"
				)
			)
			sync_after_set()
		end,
	})
end

--- 选择 DAP 日志级别
local function set_debuglog()
	local dap = require("dap")
	local desc = {
		TRACE = "追踪：最详细的日志信息",
		DEBUG = "调试：调试信息",
		INFO = "信息：一般信息，默认级别",
		WARN = "警告：警告信息",
		ERROR = "错误：错误信息",
	}
	vim.ui.select({ "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }, {
		prompt = "📊 选择 DAP 日志级别:",
		format_item = function(item)
			return string.format("📝 %-10s . %s", item, desc[item])
		end,
	}, function(choice)
		if choice then
			dap.set_log_level(choice)
			print(string.format("✔️ DAP 日志级别设置为: %s", choice))
		else
			print("❌ 未选择日志级别，操作已取消")
		end
	end)
end

function M.setup()
	local dap = require("dap")
	local dap_ext = require("dap-extensions")
	local breakpoint_state = require("dap_ext.breakpoint_state")
	local widgets = require("dap.ui.widgets")
	local sidebar = nil

	-- ▶ 控制
	vim.keymap.set("n", "<leader>dr", dap.continue, { desc = "[D]ap [C]ontinue / [S]tart" })

	-- 运行本项目上次使用的调试配置（无 picker；无记录时回退到选择器）
	vim.keymap.set("n", "<leader>dL", function()
		require("dap_ext.persist").continue_last(0)
	end, { desc = "[D]ap [L]ast config" })

	-- 生成项目调试配置模板 .nvim/dap.lua
	vim.keymap.set("n", "<leader>dP", function()
		require("dap_ext.project").init(0)
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

	-- 运行到光标：会话内 <S-Right>，见下方 step_keys / arrows
	-- 跳到指定行需要输入行号，不是“移动一步”，所以保留命令式 <leader>dg
	local function goto_line()
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
	end

	vim.keymap.set("n", "<leader>dg", goto_line, { desc = "[D]ap [G]oto line" })

	-- 💡 断点管理
	vim.keymap.set("n", "<leader>db", function()
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
		set_conditional_breakpoint()
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

	-- 启用/禁用断点
	vim.keymap.set("n", "<leader>dt", function()
		dap_ext.commands.toggle_breakpoint_enabled()
	end, { desc = "[D]ap [T]oggle breakpoint enabled/disabled" })

	-- 删除当前行断点
	vim.keymap.set("n", "<leader>dD", function()
		dap_ext.delete_breakpoint_at_current_line()
	end, { desc = "[D]ap [D]elete breakpoint at current line" })

	-- 选择删除断点
	vim.keymap.set("n", "<leader>dS", function()
		dap_ext.toggle_breakpoint_deletion()
	end, { desc = "[D]ap [S]elect breakpoint to delete" })

	-- 查看所有断点（扩展断点）
	vim.keymap.set("n", "<leader>dla", function()
		dap_ext.commands.list_breakpoints()
	end, { desc = "[D]ap List all breakpoints" })

	-- 查询并显示调试器能力
	vim.keymap.set("n", "<leader>dvc", function()
		require("dap-extensions.capabilities").show()
	end, { desc = "[D]ap Show [C]a[P]abilities" })

	-- 清除所有断点
	vim.keymap.set("n", "<leader>dC", function()
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
	vim.keymap.set("n", "<leader>dve", "<cmd>DapEval<cr>", { desc = "[D]ap [E]val expression" })
	vim.keymap.set("n", "<leader>dvr", function()
		dap.repl.toggle()
	end, { desc = "[D]ap [R]EPL toggle" })

	-- 🔧 作用域 / 堆栈 / 会话 / 线程
	vim.keymap.set("n", "<leader>dvs", function()
		if not sidebar then
			sidebar = widgets.sidebar(widgets.scopes, { width = 40, winblend = 15, signcolumn = "no" })
		end
		sidebar.toggle()
	end, { desc = "[D]ap [S]copes sidebar" })

	vim.keymap.set("n", "<leader>dvf", function()
		widgets.cursor_float(widgets.frames, { border = "rounded" })
	end, { desc = "[D]ap [F]rames float" })

	vim.keymap.set("n", "<leader>dvt", function()
		widgets.cursor_float(widgets.threads, { border = "rounded" })
	end, { desc = "[D]ap [T]hreads float" })

	vim.keymap.set("n", "<leader>dvS", function()
		widgets.cursor_float(widgets.sessions, { border = "rounded" })
	end, { desc = "[D]ap [S]essions float" })

	-- 日志相关
	vim.keymap.set("n", "<leader>dvl", "<cmd>DapShowLog<cr>", { desc = "[D]ap [L]og show" })
	vim.keymap.set("n", "<leader>dvL", set_debuglog, { desc = "[D]ap [L]og level set" })

	-- 查看光标下变量 / 自动刷新表达式
	vim.keymap.set("n", "<leader>dvE", function()
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
		-- 处理 K（DAP hover）与 [d / ]d（frame up/down）的覆盖与恢复。
		-- active_sessions 记录仍在调试的会话 id：多会话 / restart 时只保存一次原始映射，
		-- 只在最后一个会话结束时恢复，避免误删或把 DAP 映射当作原始映射。
		-- 释放挂在 event_terminated 和 on_session 两处：terminate / disconnect / 进程被杀
		-- 时适配器不一定发 terminated 事件，只靠 terminated 会残留 DAP 键位。
		local override_keys = { "K", "[d", "]d" }
		-- 单步用方向键表达语义：→ 进入、← 退出、↓ 步过、↑ 步回。
		-- `Shift+←` 是“继续跑到光标处”（run to cursor），和单步同属“移动执行位置”。
		-- 归一化模式下方向键是内建行为而不是映射，调试结束后删掉覆盖就自动还原默认功能。
		local step_keys = { "<Right>", "<Left>", "<Down>", "<Up>", "<S-Right>" }
		local hover_desc = "[D]ap [H]over"
		local saved_globals = {} -- lhs -> map（全局映射）
		local saved_buffers = {} -- 各 buffer 的局部映射
		local active_sessions = {} -- session id -> true
		local overridden = false

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

		local function set_dap_keys()
			vim.keymap.set("n", "K", function()
				require("dap.ui.widgets").hover()
			end, { silent = true, desc = hover_desc })

			vim.keymap.set("n", "[d", function()
				require("dap").up()
			end, { silent = true, desc = "[D]ap [U]p frame" })

			vim.keymap.set("n", "]d", function()
				require("dap").down()
			end, { silent = true, desc = "[D]ap [D]own frame" })

			local arrows = {
				{ "<Right>", "step_into", "[D]ap [I]nto →" },
				{ "<Left>", "step_out", "[D]ap [O]ut ←" },
				{ "<Down>", "step_over", "[D]ap [O]ver ↓" },
				{ "<Up>", "step_back", "[D]ap [B]ack ↑" },
				{ "<S-Right>", "run_to_cursor", "[D]ap [R]un to [C]ursor ⇧→" },
			}
			for _, item in ipairs(arrows) do
				local key, action, desc = item[1], item[2], item[3]
				vim.keymap.set("n", key, function()
					require("dap")[action]()
				end, { silent = true, desc = desc })
			end
		end

		--- 会话开始：第一个会话负责切换编辑器状态并覆盖键位
		local function activate(session)
			local id = session and session.id or "unknown"
			if active_sessions[id] then
				return
			end
			local first = next(active_sessions) == nil
			active_sessions[id] = true
			if not first then
				return
			end

			vim.g.dap_active = true
			require("lib.context").set_debug(true)
			pcall(vim.lsp.inlay_hint.enable, false)
			pcall(vim.diagnostic.enable, false)
			pcall(function()
				require("dap-view").virtual_text_enable()
			end)

			if overridden then
				return
			end
			overridden = true
			for _, key in ipairs(override_keys) do
				save_global_keymap(key)
				save_buffer_keymaps(key)
			end
			-- 方向键只覆盖全局映射，不动各 buffer 的局部键位
			for _, key in ipairs(step_keys) do
				save_global_keymap(key)
			end
			set_dap_keys()
		end

		--- 会话结束：最后一个会话结束时恢复键位与编辑器状态
		local function release(session_id)
			if session_id then
				active_sessions[session_id] = nil
			end
			if next(active_sessions) ~= nil then
				return
			end
			-- 没配对过 activate（适配器未初始化就退出）时不删任何映射
			if not overridden then
				return
			end
			overridden = false

			for _, key in ipairs(override_keys) do
				pcall(vim.keymap.del, "n", key)
			end
			for _, key in ipairs(step_keys) do
				pcall(vim.keymap.del, "n", key)
			end
			-- 兜底：会话期间新建 buffer 上设的 DAP hover 局部映射不在 saved_buffers 里，
			-- 按 desc 精确清掉，避免残留 K
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
					if map.lhs == "K" and map.desc == hover_desc then
						pcall(vim.api.nvim_buf_del_keymap, buf, "n", "K")
					end
				end
			end
			restore_all()

			vim.g.dap_active = false
			require("lib.context").set_debug(false)
			pcall(vim.lsp.inlay_hint.enable, true)
			pcall(vim.diagnostic.enable, true)
			pcall(function()
				require("dap-view").virtual_text_disable()
			end)
		end

		dap.listeners.after["event_initialized"]["me"] = function(session)
			activate(session)
		end

		dap.listeners.after["event_terminated"]["me"] = function(session)
			release(session and session.id)
		end

		-- 兜底：terminate / disconnect / 调试进程被杀时不一定会收到 terminated 事件，
		-- 但会话关闭一定会走 set_session(nil)，借此释放键位
		dap.listeners.on_session["me_keys"] = function(old, new)
			if old and old.closed and (not new or new.id ~= old.id) then
				release(old.id)
			end
		end
	end
end

return M
