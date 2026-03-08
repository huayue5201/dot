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

-- 将 contains 函数提前定义
local function contains(arr, item)
	for _, v in ipairs(arr) do
		if v.filter == item.filter then
			return true
		end
	end
	return false
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
	local max_width = 40 -- 最小宽度（从50减小到40）
	for _, item in ipairs(items) do
		local line = item.label
		if item.description ~= "" then
			line = line .. " - " .. item.description
		end
		-- 加上图标和空格的宽度（图标2字符 + 空格1字符）
		local width = #line + 3
		if width > max_width then
			max_width = width
		end
	end
	-- 提示行宽度
	local hint_width = #"回车: 切换 | v: 批量 | q/ESC: 关 | C-s: 完成" -- 简化提示文本
	if hint_width > max_width then
		max_width = hint_width
	end
	-- 加上边框和内边距
	return math.min(max_width + 4, 90) -- 最大不超过90（从100减小）
end

-- 创建自定义选择器，支持回车切换和v键批量选择
local function create_custom_picker(items, prompt, on_done)
	local buf = vim.api.nvim_create_buf(false, true)
	local adapter_name = get_current_adapter_name()
	local title_text = adapter_name and string.format("%s", adapter_name)

	-- 计算窗口大小 - 调小窗口
	local win_height = math.min(math.max(#items + 1, 4), 12) -- 减小最小高度和最大高度
	local win_width = calculate_width(items)

	-- 简化页脚提示文本
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
		footer = { { footer_text, "Comment" } }, -- 使用 Comment 高亮组
		footer_pos = "center",
	})

	-- 设置缓冲区选项
	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "dap-exception-breakpoints"

	-- 写入内容（只写选项，不写提示行）
	local function render_lines()
		local lines = {}
		for i, item in ipairs(items) do
			-- 使用不同图标：选中用勾，未选中用叉
			local icon = item.selected and icons.selected or icons.unselected
			local line = icon .. " " .. item.label
			if item.description ~= "" then
				line = line .. " - " .. item.description
			end
			table.insert(lines, line)
		end
		return lines
	end

	local function update_content()
		local lines = render_lines()
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		-- 清除所有高亮
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

		-- 重新设置语法高亮
		for i, item in ipairs(items) do
			-- 图标高亮：选中用绿色，未选中用红色
			if item.selected then
				vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticOk", i - 1, 0, 2) -- 绿色勾
			else
				vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticError", i - 1, 0, 2) -- 红色叉
			end
		end
	end

	update_content()

	-- 获取当前光标所在行的item
	local function get_current_item()
		local cursor = vim.api.nvim_win_get_cursor(win)
		local line = cursor[1] -- 已经是1索引
		if line >= 1 and line <= #items then
			return items[line], line
		end
		return nil, nil
	end

	-- 切换当前行的选中状态
	local function toggle_current()
		local item, idx = get_current_item()
		if not item then
			return
		end

		if contains(selected_options, item._opt) then
			for i, v in ipairs(selected_options) do
				if v.filter == item._opt.filter then
					table.remove(selected_options, i)
					break
				end
			end
			item.selected = false
		else
			table.insert(selected_options, item._opt)
			item.selected = true
		end

		update_content()
	end

	-- 批量选择模式
	local function start_batch_select()
		-- 进入可视模式
		vim.cmd("normal! V")

		-- 设置可视模式下的键映射
		vim.keymap.set("v", "v", function()
			-- 退出可视模式并应用选择
			local start_line = vim.fn.line("'<")
			local end_line = vim.fn.line("'>")

			-- 切换选中区域内所有项
			for i = start_line, end_line do
				local item = items[i]
				if item then
					if contains(selected_options, item._opt) then
						for j, v in ipairs(selected_options) do
							if v.filter == item._opt.filter then
								table.remove(selected_options, j)
								break
							end
						end
						item.selected = false
					else
						table.insert(selected_options, item._opt)
						item.selected = true
					end
				end
			end

			update_content()
			vim.cmd("stopinsert")
		end, { buffer = buf, nowait = true })
	end

	-- 设置快捷键
	local opts = { buffer = buf, nowait = true }

	-- 取消选择（不保存，直接关闭）
	local function cancel_and_close()
		-- 恢复之前的选中状态（从原始 available_options 重建 selected_options）
		selected_options = {}
		for _, opt in ipairs(available_options) do
			if opt.default then
				table.insert(selected_options, opt)
			end
		end
		vim.api.nvim_win_close(win, true)
	end

	-- q 键：关闭浮窗（不保存）
	vim.keymap.set("n", "q", function()
		cancel_and_close()
	end, opts)

	-- ESC 键：关闭浮窗（不保存）
	vim.keymap.set("n", "<Esc>", function()
		cancel_and_close()
	end, opts)

	-- Ctrl-s 键：完成并保存
	vim.keymap.set("n", "<C-s>", function()
		vim.api.nvim_win_close(win, true)
		if on_done then
			on_done(true)
		end
	end, opts)

	-- 回车切换当前行
	vim.keymap.set("n", "<CR>", function()
		toggle_current()
	end, opts)

	-- v键进入批量选择模式
	vim.keymap.set("n", "v", function()
		start_batch_select()
	end, opts)

	-- 数字键直接选择
	for i = 1, #items do
		vim.keymap.set("n", tostring(i), function()
			local item = items[i]
			if item then
				if contains(selected_options, item._opt) then
					for j, v in ipairs(selected_options) do
						if v.filter == item._opt.filter then
							table.remove(selected_options, j)
							break
						end
					end
					item.selected = false
				else
					table.insert(selected_options, item._opt)
					item.selected = true
				end
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

	-- 设置光标位置
	vim.api.nvim_win_set_cursor(win, { 1, 0 })

	-- 自动命令：窗口关闭时清理
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end,
	})
end

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
	set_exception_breakpoints()
end

function M.toggle()
	if not available_options then
		vim.notify("请先启动一次调试器以加载异常断点选项", vim.log.levels.WARN)
		return
	end

	local function redraw()
		local items = {}
		for _, opt in ipairs(available_options) do
			table.insert(items, {
				label = opt.label,
				description = opt.description or "",
				filter = opt.filter,
				selected = contains(selected_options, opt),
				_opt = opt,
			})
		end

		table.sort(items, function(a, b)
			return a.label < b.label
		end)

		create_custom_picker(items, nil, function(completed)
			if completed then
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
			end
		end)
	end

	redraw()
end

return M
