-- exception-breakpoints.lua（丝滑 + 高亮版）

local M = {}
local dap = require("dap")

local available_options = nil
local selected_options = nil

-- 图标定义
local icons = {
	selected = " ", -- 选中图标（绿色勾）
	unselected = " ", -- 未选中图标（红色叉）
}

-- 判断选项是否在选中列表中
local function is_option_selected(opt)
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

-- 切换选项的选中状态
local function toggle_option(opt)
	if not opt then
		return
	end

	for i, v in ipairs(selected_options) do
		if v.filter == opt.filter then
			table.remove(selected_options, i)
			return false -- 返回新状态：未选中
		end
	end

	table.insert(selected_options, opt)
	return true -- 返回新状态：选中
end

-- 获取当前调试适配器名称
local function get_current_adapter_name()
	local session = dap.session()
	if session and session.config then
		return session.config.type or "unknown"
	end
	return nil
end

-- 计算文本宽度
local function calculate_width(items)
	local max_width = 40
	for _, item in ipairs(items) do
		local line = item.label
		if item.description ~= "" then
			line = line .. " - " .. item.description
		end
		local width = #line + 3
		if width > max_width then
			max_width = width
		end
	end

	local hint_width = #"回车: 切换 | v: 批量 | q/ESC: 关 | C-s: 完成"
	if hint_width > max_width then
		max_width = hint_width
	end

	return math.min(max_width + 4, 90)
end

-- 创建自定义选择器
local function create_custom_picker(items, on_done)
	local buf = vim.api.nvim_create_buf(false, true)
	local adapter_name = get_current_adapter_name()
	local title_text = adapter_name and string.format(" %s ", adapter_name)

	-- 计算窗口大小
	local win_height = math.min(math.max(#items + 1, 4), 12)
	local win_width = calculate_width(items)

	local footer_text = "回车:切换 | v:批量 | q/ESC:关 | C-s:完成"

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = math.floor((vim.o.columns - win_width) / 2),
		row = math.floor((vim.o.lines - win_height) / 2),
		border = "rounded",
		style = "minimal",
		title = title_text,
		title_pos = "center",
		footer = { { footer_text, "Comment" } },
		footer_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "dap-exception-breakpoints"

	-- 更新显示内容
	local function update_content()
		-- 生成显示行
		local lines = {}
		for _, item in ipairs(items) do
			local icon = item.selected and icons.selected or icons.unselected
			local line = icon .. " " .. item.label
			if item.description ~= "" then
				line = line .. " - " .. item.description
			end
			table.insert(lines, line)
		end

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		-- 重新设置高亮
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		for i, item in ipairs(items) do
			local hl_group = item.selected and "DiagnosticOk" or "DiagnosticError"
			vim.api.nvim_buf_add_highlight(buf, -1, hl_group, i - 1, 0, 2)
		end
	end

	-- 切换当前行的选中状态
	local function toggle_current()
		local cursor = vim.api.nvim_win_get_cursor(win)
		local line = cursor[1]
		if line >= 1 and line <= #items then
			local item = items[line]
			item.selected = toggle_option(item._opt)
			update_content()
		end
	end

	-- 批量切换选中状态
	local function batch_toggle(start_line, end_line)
		for i = start_line, end_line do
			local item = items[i]
			if item then
				item.selected = toggle_option(item._opt)
			end
		end
		update_content()
	end

	-- 重置选择为默认值
	local function reset_to_default()
		selected_options = {}
		for _, opt in ipairs(available_options) do
			if opt.default then
				table.insert(selected_options, opt)
			end
		end

		-- 更新 items 的选中状态
		for _, item in ipairs(items) do
			item.selected = is_option_selected(item._opt)
		end
	end

	-- 批量选择模式
	local function start_batch_select()
		vim.cmd("normal! V")
		vim.keymap.set("v", "v", function()
			local start_line = vim.fn.line("'<")
			local end_line = vim.fn.line("'>")
			batch_toggle(start_line, end_line)
			vim.cmd("stopinsert")
		end, { buffer = buf, nowait = true })
	end

	-- 取消选择并关闭
	local function cancel_and_close()
		reset_to_default()
		vim.api.nvim_win_close(win, true)
	end

	-- 完成选择并关闭
	local function complete_and_close()
		vim.api.nvim_win_close(win, true)
		if on_done then
			on_done()
		end
	end

	-- 设置快捷键
	local opts = { buffer = buf, nowait = true }
	vim.keymap.set("n", "q", cancel_and_close, opts)
	vim.keymap.set("n", "<Esc>", cancel_and_close, opts)
	vim.keymap.set("n", "<C-s>", complete_and_close, opts)
	vim.keymap.set("n", "<CR>", toggle_current, opts)
	vim.keymap.set("n", "v", start_batch_select, opts)

	-- 数字键直接选择
	for i = 1, #items do
		vim.keymap.set("n", tostring(i), function()
			local item = items[i]
			if item then
				item.selected = toggle_option(item._opt)
				update_content()
			end
		end, opts)
	end

	-- 上下移动
	vim.keymap.set("n", "j", function()
		local cursor = vim.api.nvim_win_get_cursor(win)
		if cursor[1] < #items then
			vim.api.nvim_win_set_cursor(win, { cursor[1] + 1, cursor[2] })
		end
	end, opts)

	vim.keymap.set("n", "k", function()
		local cursor = vim.api.nvim_win_get_cursor(win)
		if cursor[1] > 1 then
			vim.api.nvim_win_set_cursor(win, { cursor[1] - 1, cursor[2] })
		end
	end, opts)

	-- 初始化显示
	update_content()
	vim.api.nvim_win_set_cursor(win, { 1, 0 })

	-- 窗口关闭时清理
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end,
	})
end

-- 设置异常断点
local function set_exception_breakpoints()
	if not selected_options then
		return
	end

	local filters = {}
	for _, opt in ipairs(selected_options) do
		table.insert(filters, opt.filter)
	end
	dap.set_exception_breakpoints(filters)
end

-- 监听器：初始化选项
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

-- 监听器：启动时设置
dap.listeners.after["launch"]["exception_breakpoints_ui"] = function()
	set_exception_breakpoints()
end

-- 主功能：切换异常断点选择
function M.toggle()
	if not available_options then
		vim.notify("调试器未启动", vim.log.levels.WARN)
		return
	end

	-- 准备显示项
	local items = {}
	for _, opt in ipairs(available_options) do
		table.insert(items, {
			label = opt.label,
			description = opt.description or "",
			filter = opt.filter,
			selected = is_option_selected(opt),
			_opt = opt,
		})
	end

	table.sort(items, function(a, b)
		return a.label < b.label
	end)

	-- 创建选择器
	create_custom_picker(items, function()
		if dap.session() then
			set_exception_breakpoints()
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
