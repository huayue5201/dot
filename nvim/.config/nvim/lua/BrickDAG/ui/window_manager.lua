local M = {
	windows = {}, -- { left, center, right }
	views = {
		list = require("BrickDAG.ui.views.list_view"),
		detail = require("BrickDAG.ui.views.detail_view"),
	},
}

-- 定义窗口高亮组
local function define_highlight_groups()
	local defs = {
		left = { bg = "#3b4252", fg = "#b48ead" },
		center = { bg = "#434c5e", fg = "#a3be8c" },
		right = { bg = "#4c566a", fg = "#ebcb8b" },
	}

	for name, hl in pairs(defs) do
		vim.api.nvim_set_hl(0, name .. "WinNormal", { bg = hl.bg })
		vim.api.nvim_set_hl(0, name .. "WinBorder", { fg = hl.fg, bg = hl.bg })
	end
end

-- 计算窗口布局 (3:5:2 比例)
local function calculate_layout()
	local total_width = vim.o.columns
	local total_height = vim.o.lines

	local usable_width = math.floor(total_width * 0.7)
	local col_offset = math.floor((total_width - usable_width) / 2)

	local gap = 2 -- 窗口间隙
	local total_gap = gap * 2

	local height = math.floor(total_height * 0.5)
	local row = math.floor((total_height - height) / 2)

	local content_width = usable_width - total_gap
	local total_ratio = 3 + 5 + 2
	local left_w = math.floor(content_width * 3 / total_ratio)
	local center_w = math.floor(content_width * 5 / total_ratio)
	local right_w = content_width - left_w - center_w

	return {
		left = { row = row, col = col_offset, width = left_w, height = height },
		center = { row = row, col = col_offset + left_w + gap, width = center_w, height = height },
		right = { row = row, col = col_offset + left_w + gap + center_w + gap, width = right_w, height = height },
	}
end

-- 创建窗口
local function create_window(position, opts)
	local border_chars = {
		"╭",
		"─",
		"╮",
		"│",
		"╯",
		"─",
		"╰",
		"│",
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = border_chars,
		row = opts.row,
		col = opts.col,
		width = opts.width,
		height = opts.height,
		zindex = 50,
	})

	-- 设置 winhighlight
	vim.api.nvim_win_set_option(
		win,
		"winhighlight",
		string.format("Normal:%sWinNormal,FloatBorder:%sWinBorder", position, position)
	)

	return { win = win, buf = buf }
end

-- 打开所有窗口
function M.open()
	define_highlight_groups()
	M.close_all()

	local layout = calculate_layout()
	for position, opts in pairs(layout) do
		M.windows[position] = create_window(position, opts)
	end
	M.focus_center()
end

-- 关闭所有窗口
function M.close_all()
	for _, win_info in pairs(M.windows) do
		if vim.api.nvim_win_is_valid(win_info.win) then
			vim.api.nvim_win_close(win_info.win, true)
		end
	end
	M.windows = {}
end

-- 确保窗口打开
function M.ensure_open()
	if not M.windows.center or not vim.api.nvim_win_is_valid(M.windows.center.win) then
		M.open()
	end
end

-- 聚焦中间窗口
function M.focus_center()
	if M.windows.center and vim.api.nvim_win_is_valid(M.windows.center.win) then
		vim.api.nvim_set_current_win(M.windows.center.win)
	end
end

-- 安全更新缓冲区
local function safe_buf_update(buf, update_fn)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	-- 在安全上下文中执行更新
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local ok, err = pcall(function()
			local modifiable = vim.api.nvim_buf_get_option(buf, "modifiable")
			vim.api.nvim_buf_set_option(buf, "modifiable", true)
			update_fn()
			vim.api.nvim_buf_set_option(buf, "modifiable", modifiable)
		end)

		if not ok then
			vim.notify("缓冲区更新失败: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

-- 更新窗口内容
function M.update_all()
	if not M.windows.center or not vim.api.nvim_win_is_valid(M.windows.center.win) then
		return
	end

	local state = require("BrickDAG.ui.state_machine")
	local nav_stack = state.get_nav_stack()
	local current_layer = state.current_layer()
	if not current_layer then
		return
	end

	-- 左侧窗口（上一层）
	if #nav_stack > 1 then
		local prev_layer = nav_stack[#nav_stack - 1]
		M.update_view("left", "list", {
			items = prev_layer.current,
			selected_index = prev_layer.selected_index,
			layer_type = prev_layer.type,
		})
	else
		M.clear_window("left")
	end

	-- 中间窗口（当前层）
	M.update_view("center", "list", {
		items = current_layer.current,
		selected_index = current_layer.selected_index,
		layer_type = current_layer.type,
	})

	-- 右侧窗口（始终显示源任务的积木参数值）
	local source_task = current_layer.source_task or current_layer.current[current_layer.selected_index]
	local detail_data = {}

	-- 获取源任务的积木参数值
	if source_task and source_task.type and source_task[source_task.type] then
		detail_data = {
			item = {
				value = source_task[source_task.type],
			},
		}
	end

	M.update_view("right", "detail", detail_data)
end

-- 更新特定视图
function M.update_view(position, view_type, data)
	if not M.windows[position] then
		return
	end

	local win_info = M.windows[position]
	if not vim.api.nvim_win_is_valid(win_info.win) then
		return
	end

	local view = M.views[view_type]
	if not view then
		return
	end

	safe_buf_update(win_info.buf, function()
		view.render(win_info.buf, data)
	end)
end

-- 清空窗口
function M.clear_window(position)
	if not M.windows[position] then
		return
	end

	local win_info = M.windows[position]
	if not win_info.buf or not vim.api.nvim_buf_is_valid(win_info.buf) then
		return
	end

	safe_buf_update(win_info.buf, function()
		vim.api.nvim_buf_set_lines(win_info.buf, 0, -1, false, {})
	end)
end

-- 检查是否在导航界面中
function M.is_in_navigation()
	return M.windows.center and vim.api.nvim_win_is_valid(M.windows.center.win)
end

return M
