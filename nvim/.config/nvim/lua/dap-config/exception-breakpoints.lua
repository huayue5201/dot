-- exception-breakpoints.lua（自动 fallback + 完整异常树 UI + 原 UI 完全保留，无 footer）

local M = {}
local dap = require("dap")

---------------------------------------------------------------------
-- 原 filters 模式数据
---------------------------------------------------------------------
local available_options = nil
local selected_options = nil

local icons = {
	selected = "  ",
	unselected = "  ",
}

local function is_selected(opt)
	if not selected_options then
		return false
	end
	for _, v in ipairs(selected_options) do
		if v.filter == opt.filter then
			return true
		end
	end
	return false
end

local function toggle_option(opt)
	for i, v in ipairs(selected_options) do
		if v.filter == opt.filter then
			table.remove(selected_options, i)
			return false
		end
	end
	table.insert(selected_options, opt)
	return true
end

local function get_adapter_name()
	local session = dap.session()
	return session and session.config and session.config.type or "unknown"
end

local function calc_width(items)
	local max_width = 40
	for _, item in ipairs(items) do
		local text = item.label
		if item.description ~= "" then
			text = text .. " - " .. item.description
		end
		max_width = math.max(max_width, #text + 3)
	end
	return math.min(max_width + 4, 40)
end

local function render(buf, items)
	local lines = {}
	for _, item in ipairs(items) do
		local selected = is_selected(item._opt)
		local icon = selected and icons.selected or icons.unselected
		local line = icon .. " " .. item.label
		if item.description ~= "" then
			line = line .. " - " .. item.description
		end
		table.insert(lines, line)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

	for i, item in ipairs(items) do
		local selected = is_selected(item._opt)
		local hl = selected and "DiagnosticOk" or "DiagnosticError"
		vim.api.nvim_buf_add_highlight(buf, -1, hl, i - 1, 0, 2)
	end
end

---------------------------------------------------------------------
-- filters UI（你的原 UI，完全保留）
---------------------------------------------------------------------
local function create_picker(items, on_done)
	local buf = vim.api.nvim_create_buf(false, true)
	local adapter = get_adapter_name()

	local width = calc_width(items)
	local height = math.min(math.max(#items + 1, 3), 12)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		style = "minimal",
		title = " " .. adapter .. " ",
		title_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"

	local function apply_toggle(i)
		local item = items[i]
		if item then
			toggle_option(item._opt)
			render(buf, items)
		end
	end

	local function cursor_line()
		return vim.api.nvim_win_get_cursor(win)[1]
	end

	local function batch_toggle()
		local s = vim.fn.line("'<")
		local e = vim.fn.line("'>")
		for i = s, e do
			local item = items[i]
			if item then
				toggle_option(item._opt)
			end
		end
		render(buf, items)
	end

	local function reset_default()
		selected_options = {}
		for _, opt in ipairs(available_options) do
			if opt.default then
				table.insert(selected_options, opt)
			end
		end
	end

	local function close_cancel()
		reset_default()
		vim.api.nvim_win_close(win, true)
	end

	local function close_done()
		vim.api.nvim_win_close(win, true)
		if on_done then
			on_done()
		end
	end

	local opts = { buffer = buf, nowait = true }

	-- 关键：CR = 切换状态（你的原逻辑）
	vim.keymap.set("n", "<CR>", function()
		apply_toggle(cursor_line())
	end, opts)

	vim.keymap.set("n", "<Tab>", close_done, opts)
	vim.keymap.set("n", "<C-s>", close_done, opts)

	vim.keymap.set("n", "q", close_cancel, opts)
	vim.keymap.set("n", "<Esc>", close_cancel, opts)

	vim.keymap.set("n", "v", function()
		vim.cmd("normal! V")
		vim.keymap.set("v", "v", function()
			batch_toggle()
			vim.cmd("stopinsert")
		end, { buffer = buf, nowait = true })
	end, opts)

	vim.keymap.set("n", "j", function()
		local c = cursor_line()
		if c < #items then
			vim.api.nvim_win_set_cursor(win, { c + 1, 0 })
		end
	end, opts)

	vim.keymap.set("n", "k", function()
		local c = cursor_line()
		if c > 1 then
			vim.api.nvim_win_set_cursor(win, { c - 1, 0 })
		end
	end, opts)

	for i = 1, #items do
		vim.keymap.set("n", tostring(i), function()
			apply_toggle(i)
		end, opts)
	end

	render(buf, items)
	vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

local function apply_exception_breakpoints()
	if not selected_options then
		return
	end
	local filters = {}
	for _, opt in ipairs(selected_options) do
		table.insert(filters, opt.filter)
	end
	dap.set_exception_breakpoints(filters)
end

---------------------------------------------------------------------
-- 完整异常树 UI（ExceptionOptions）
-- 交互逻辑完全遵循 filters UI：CR 切换、Tab 完成
---------------------------------------------------------------------
local function open_full_exception_ui(session)
	local tree = session.capabilities.exceptionOptions
	if not tree then
		return false
	end

	local function flatten(node, depth, out)
		out = out or {}
		table.insert(out, { name = node.name, depth = depth, node = node })
		if node.children then
			for _, c in ipairs(node.children) do
				flatten(c, depth + 1, out)
			end
		end
		return out
	end

	local flat = flatten(tree, 0)
	local selection = {}

	local function render_tree(buf)
		local lines = {}
		for _, item in ipairs(flat) do
			local indent = string.rep("  ", item.depth)
			local sel = selection[item.name]
			local icon = sel and "  " or "  "
			table.insert(lines, indent .. icon .. item.name)
		end
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		for i, item in ipairs(flat) do
			local sel = selection[item.name]
			local hl = sel and "DiagnosticOk" or "DiagnosticError"
			vim.api.nvim_buf_add_highlight(buf, -1, hl, i - 1, 0, 3)
		end
	end

	local BREAK_MODES = { "always", "unhandled", "userUnhandled", "never" }

	local function choose_break_mode(name, on_done)
		local buf = vim.api.nvim_create_buf(false, true)
		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = 30,
			height = #BREAK_MODES + 2,
			col = math.floor((vim.o.columns - 30) / 2),
			row = math.floor((vim.o.lines - (#BREAK_MODES + 2)) / 2),
			border = "rounded",
			style = "minimal",
			title = " Break Mode ",
			title_pos = "center",
		})

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, BREAK_MODES)

		vim.keymap.set("n", "<CR>", function()
			local line = vim.api.nvim_win_get_cursor(win)[1]
			on_done(BREAK_MODES[line])
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf })

		vim.keymap.set("n", "q", function()
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf })
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local adapter = get_adapter_name()

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = 50,
		height = math.min(#flat + 2, 20),
		col = math.floor((vim.o.columns - 50) / 2),
		row = math.floor((vim.o.lines - 20) / 2),
		border = "rounded",
		style = "minimal",
		title = " " .. adapter .. " Exceptions ",
		title_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"

	render_tree(buf)

	local function cursor_line()
		return vim.api.nvim_win_get_cursor(win)[1]
	end

	local opts = { buffer = buf, nowait = true }

	-- CR = 切换选中状态（与你原 UI 完全一致）
	vim.keymap.set("n", "<CR>", function()
		local i = cursor_line()
		local name = flat[i].name
		if selection[name] then
			selection[name] = nil
		else
			selection[name] = { breakMode = "always", negate = false }
		end
		render_tree(buf)
	end, opts)

	-- b = breakMode
	vim.keymap.set("n", "b", function()
		local i = cursor_line()
		local name = flat[i].name
		if not selection[name] then
			selection[name] = { breakMode = "always", negate = false }
		end
		choose_break_mode(name, function(mode)
			selection[name].breakMode = mode
			render_tree(buf)
		end)
	end, opts)

	-- n = negate
	vim.keymap.set("n", "n", function()
		local i = cursor_line()
		local name = flat[i].name
		if not selection[name] then
			selection[name] = { breakMode = "always", negate = false }
		end
		selection[name].negate = not selection[name].negate
		render_tree(buf)
	end, opts)

	-- j/k = 上下移动
	vim.keymap.set("n", "j", function()
		local c = cursor_line()
		if c < #flat then
			vim.api.nvim_win_set_cursor(win, { c + 1, 0 })
		end
	end, opts)

	vim.keymap.set("n", "k", function()
		local c = cursor_line()
		if c > 1 then
			vim.api.nvim_win_set_cursor(win, { c - 1, 0 })
		end
	end, opts)

	-- q / ESC = 关闭
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, opts)

	-- Tab / C-s = 完成（与你原 UI 完全一致）
	local function finish()
		vim.api.nvim_win_close(win, true)

		local result = {}

		local function walk(node, path)
			local name = node.name
			local sel = selection[name]

			local new_path = vim.deepcopy(path)
			table.insert(new_path, {
				names = { name },
				negate = sel and sel.negate or false,
			})

			if sel then
				table.insert(result, {
					path = new_path,
					breakMode = sel.breakMode or "always",
				})
			end

			if node.children then
				for _, c in ipairs(node.children) do
					walk(c, new_path)
				end
			end
		end

		walk(tree, {})
		dap.set_exception_breakpoints(nil, result)
		vim.notify("已应用完整异常断点", vim.log.levels.INFO)
	end

	vim.keymap.set("n", "<Tab>", finish, opts)
	vim.keymap.set("n", "<C-s>", finish, opts)

	return true
end

---------------------------------------------------------------------
-- 自动 fallback：完整模式 → filters 模式
---------------------------------------------------------------------
local function supports_full_exception_options(session)
	return session and session.capabilities and session.capabilities.exceptionOptions ~= nil
end

---------------------------------------------------------------------
-- 初始化 filters
---------------------------------------------------------------------
dap.listeners.after["configurationDone"]["exception_breakpoints_ui"] = function(session)
	local opts = session.capabilities.exceptionBreakpointFilters
	if not opts then
		available_options = nil
		selected_options = nil
		return
	end

	available_options = opts
	selected_options = {}
	for _, opt in ipairs(opts) do
		if opt.default then
			table.insert(selected_options, opt)
		end
	end
end

dap.listeners.after["launch"]["exception_breakpoints_ui"] = function()
	apply_exception_breakpoints()
end

---------------------------------------------------------------------
-- 主入口（自动 fallback）
---------------------------------------------------------------------
function M.toggle()
	local session = dap.session()
	if not session then
		vim.notify("调试器未启动", vim.log.levels.WARN)
		return
	end

	-- 优先完整异常断点 UI
	if supports_full_exception_options(session) then
		local ok = open_full_exception_ui(session)
		if ok then
			return
		end
	end

	-- fallback 到 filters UI
	if not available_options then
		vim.notify("当前调试器不支持异常断点", vim.log.levels.WARN)
		return
	end

	local items = {}
	for _, opt in ipairs(available_options) do
		table.insert(items, {
			label = opt.label,
			description = opt.description or "",
			filter = opt.filter,
			_opt = opt,
		})
	end

	table.sort(items, function(a, b)
		return a.label < b.label
	end)

	create_picker(items, function()
		if dap.session() then
			apply_exception_breakpoints()
		end
	end)
end

return M
