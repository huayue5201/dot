local M = {
	windows = {}, -- { left, center, right }
	views = {
		list = require("brickdag.ui.views.list_view"),
		detail = require("brickdag.ui.views.detail_view"),
	},
}

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
	local total_ratio = 3 + 3 + 3
	local left_w = math.floor(content_width * 3 / total_ratio)
	local center_w = math.floor(content_width * 3 / total_ratio)
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

	local state = require("brickdag.ui.state_machine")
	local nav_stack = state.get_nav_stack()
	local current_layer = state.current_layer()

	if not current_layer or not nav_stack then
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

	-- 右侧窗口（预览下一层）
	local selected = current_layer.current[current_layer.selected_index]
	if not selected then
		M.clear_window("right")
		return
	end

	-- 根据当前层级和选中项决定预览内容
	if current_layer.type == state.LAYER_TYPES.TASK_LIST then
		-- 预览积木框架或基础积木
		local preview_items = {}

		if selected.type == "frame" then
			-- 框架积木：预览其基础积木
			if selected.frame then
				for param, value in pairs(selected.frame) do
					table.insert(preview_items, {
						name = param,
						value = value,
						type = state.LAYER_TYPES.BASE_BRICK,
					})
				end
			end
		else
			-- 基础积木：预览其参数
			if selected[selected.type] then
				for param, value in pairs(selected[selected.type]) do
					table.insert(preview_items, {
						name = param,
						value = value,
						type = state.LAYER_TYPES.BASE_BRICK,
					})
				end
			end
		end

		-- 添加依赖任务
		if selected.deps then
			for _, dep_name in ipairs(selected.deps) do
				for _, task in ipairs(state.root_tasks) do
					if task.name == dep_name then
						table.insert(preview_items, {
							name = task.name,
							value = task,
							type = state.LAYER_TYPES.TASK_LIST,
							is_dependency = true,
						})
						break
					end
				end
			end
		end

		if #preview_items > 0 then
			M.update_view("right", "list", {
				items = preview_items,
				selected_index = 1,
				layer_type = state.LAYER_TYPES.FRAME_BRICK,
			})
		else
			M.update_view("right", "detail", {
				item = selected,
			})
		end
	elseif current_layer.type == state.LAYER_TYPES.FRAME_BRICK then
		if selected.type == state.LAYER_TYPES.BASE_BRICK then
			-- 预览基础积木的参数值
			if type(selected.value) == "table" then
				local values = {}
				if vim.tbl_islist(selected.value) then
					-- 数组值
					for _, v in ipairs(selected.value) do
						table.insert(values, {
							value = v,
							type = state.LAYER_TYPES.VALUE,
						})
					end
				else
					-- 字典值
					for k, v in pairs(selected.value) do
						table.insert(values, {
							name = k,
							value = v,
							type = state.LAYER_TYPES.VALUE,
						})
					end
				end

				if #values > 0 then
					M.update_view("right", "list", {
						items = values,
						selected_index = 1,
						layer_type = state.LAYER_TYPES.BASE_BRICK,
					})
				else
					M.update_view("right", "detail", {
						item = selected,
					})
				end
			else
				M.update_view("right", "detail", {
					item = selected,
				})
			end
		elseif selected.type == state.LAYER_TYPES.TASK_LIST then
			-- 预览依赖任务
			local preview_items = {}

			if selected.value.type == "frame" then
				-- 框架积木：预览其基础积木
				if selected.value.frame then
					for param, value in pairs(selected.value.frame) do
						table.insert(preview_items, {
							name = param,
							value = value,
							type = state.LAYER_TYPES.BASE_BRICK,
						})
					end
				end
			else
				-- 基础积木：预览其参数
				if selected.value[selected.value.type] then
					for param, value in pairs(selected.value[selected.value.type]) do
						table.insert(preview_items, {
							name = param,
							value = value,
							type = state.LAYER_TYPES.BASE_BRICK,
						})
					end
				end
			end

			if #preview_items > 0 then
				M.update_view("right", "list", {
					items = preview_items,
					selected_index = 1,
					layer_type = state.LAYER_TYPES.FRAME_BRICK,
				})
			else
				M.update_view("right", "detail", {
					item = selected,
				})
			end
		else
			M.update_view("right", "detail", {
				item = selected,
			})
		end
	elseif current_layer.type == state.LAYER_TYPES.BASE_BRICK then
		-- 参数值层级不再预览
		M.update_view("right", "detail", {
			item = selected,
		})
	else
		M.clear_window("right")
	end
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
