-- exception-breakpoints.lua（丝滑 + 高亮 + 精简重构版 + footer统一）

local M = {}
local dap = require("dap")

local available_options = nil
local selected_options = nil

-- 图标
local icons = {
	selected = "  ",
	unselected = "  ",
}

-- 判断是否选中
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

-- 切换选中状态
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

-- 获取当前 adapter 名称
local function get_adapter_name()
	local session = dap.session()
	return session and session.config and session.config.type or "unknown"
end

-- 计算宽度
local function calc_width(items, footer_text)
	local max_width = 40
	for _, item in ipairs(items) do
		local text = item.label
		if item.description ~= "" then
			text = text .. " - " .. item.description
		end
		max_width = math.max(max_width, #text + 3)
	end

	-- footer 统一使用同一个字符串
	max_width = math.max(max_width, #footer_text)

	return math.min(max_width + 4, 40)
end

-- 渲染器
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

	-- 高亮
	vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
	for i, item in ipairs(items) do
		local selected = is_selected(item._opt)
		local hl = selected and "DiagnosticOk" or "DiagnosticError"
		vim.api.nvim_buf_add_highlight(buf, -1, hl, i - 1, 0, 2)
	end
end

-- 创建 UI
local function create_picker(items, on_done)
	local buf = vim.api.nvim_create_buf(false, true)
	local adapter = get_adapter_name()

	-- footer 文本统一
	local footer_text = "CR:切换  v:批量  q/ESC:关  C-s:完成"

	local width = calc_width(items, footer_text)
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
		footer = { { footer_text, "Comment" } },
		footer_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "dap-exception-breakpoints"

	-- 操作函数
	local function apply_toggle(i)
		local item = items[i]
		if not item then
			return
		end
		toggle_option(item._opt)
		render(buf, items)
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

	-- 键位绑定
	local opts = { buffer = buf, nowait = true }

	local keymap = {
		q = close_cancel,
		["<Esc>"] = close_cancel,
		["<CR>"] = close_done,
		["<tab>"] = function()
			apply_toggle(cursor_line())
		end,
		v = function()
			vim.cmd("normal! V")
			vim.keymap.set("v", "v", function()
				batch_toggle()
				vim.cmd("stopinsert")
			end, { buffer = buf, nowait = true })
		end,
		j = function()
			local c = cursor_line()
			if c < #items then
				vim.api.nvim_win_set_cursor(win, { c + 1, 0 })
			end
		end,
		k = function()
			local c = cursor_line()
			if c > 1 then
				vim.api.nvim_win_set_cursor(win, { c - 1, 0 })
			end
		end,
	}

	for k, fn in pairs(keymap) do
		vim.keymap.set("n", k, fn, opts)
	end

	-- 数字键
	for i = 1, #items do
		vim.keymap.set("n", tostring(i), function()
			apply_toggle(i)
		end, opts)
	end

	-- 初次渲染
	render(buf, items)
	vim.api.nvim_win_set_cursor(win, { 1, 0 })

	-- 自动清理
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end,
	})
end

-- 设置异常断点
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

-- 初始化选项
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

-- 启动时应用
dap.listeners.after["launch"]["exception_breakpoints_ui"] = function()
	apply_exception_breakpoints()
end

-- 主入口
function M.toggle()
	if not available_options then
		vim.notify("调试器未启动", vim.log.levels.WARN)
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

		if #selected_options == 0 then
			vim.notify("已禁用所有异常断点", vim.log.levels.INFO)
		else
			local names = {}
			for _, opt in ipairs(selected_options) do
				table.insert(names, opt.label)
			end
			table.sort(names)
			vim.notify(
				"已启用 " .. #selected_options .. " 个异常断点: " .. table.concat(names, ", "),
				vim.log.levels.INFO
			)
		end
	end)
end

return M
