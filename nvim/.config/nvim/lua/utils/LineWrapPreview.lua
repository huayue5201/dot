local M = {}

-- 存储当前的浮动窗口 ID 和缓冲区 ID
local float_win_id = nil
local float_buf_id = nil
local preview_line_num = nil -- 存储预览时的行号

-- 获取当前 buffer 的 filetype
local function get_current_filetype()
	return vim.bo.filetype
end

-- 获取整个编辑器宽度
local function get_editor_width()
	return vim.o.columns
end

-- 获取整个编辑器高度
local function get_editor_height()
	return vim.o.lines
end

-- 修复：兼容不同版本的窗口位置获取
local function get_cursor_screen_position()
	local winid = vim.api.nvim_get_current_win()

	-- 兼容不同版本的 nvim_win_get_position
	local win_row, win_col
	local pos = vim.api.nvim_win_get_position(winid)
	if type(pos) == "table" then
		-- 处理返回表的情况
		win_row = pos[1]
		win_col = pos[2]
	else
		-- 处理返回两个值的情况
		win_row, win_col = pos, vim.api.nvim_win_get_position(winid)
	end

	local cursor_pos = vim.api.nvim_win_get_cursor(winid)
	local win_topline = vim.fn.line("w0", winid) -- 窗口顶部行号

	-- TODO: 部分窗口需要-1才能覆盖当前行，这点可以考虑用条件判断来修正该问题
	-- 计算光标在屏幕上的绝对行位置
	local screen_row = win_row + (cursor_pos[1] - win_topline) -- 此处+1才能正确覆盖当前行

	return {
		row = screen_row,
		col = win_col + cursor_pos[2], -- 列位置
	}
end

-- 改进的自动换行函数
local function wrap_line_if_needed(line, width)
	if #line <= width then
		return { line }
	end

	local wrapped_lines = {}
	local start_index = 1
	local line_len = #line

	while start_index <= line_len do
		local max_length = math.min(width, line_len - start_index + 1)
		local segment = line:sub(start_index, start_index + max_length - 1)

		if max_length < width then
			table.insert(wrapped_lines, segment)
			break
		end

		local last_space = nil
		for i = max_length, 1, -1 do
			if segment:sub(i, i):match("%s") then
				last_space = i
				break
			end
		end

		local end_index
		if last_space and last_space > 1 then
			end_index = start_index + last_space - 2
			table.insert(wrapped_lines, line:sub(start_index, end_index))
			start_index = end_index + 2
		elseif last_space == 1 then
			start_index = start_index + 1
		else
			end_index = start_index + max_length - 1
			table.insert(wrapped_lines, line:sub(start_index, end_index))
			start_index = end_index + 1
		end
	end

	return wrapped_lines
end

-- 获取当前行内容的最大宽度（根据内容自适应宽度）
local function get_max_line_width(line)
	-- 如果行内容为空，给它一个最小宽度
	if #line == 0 then
		return 1
	end

	local wrapped_lines = wrap_line_if_needed(line, get_editor_width() - 4) -- 用wrap_line_if_needed包装行
	local max_width = 0
	for _, l in ipairs(wrapped_lines) do
		max_width = math.max(max_width, #l)
	end
	return max_width
end

-- 创建并显示浮动窗口（根据内容调整宽度并覆盖当前行）
local function show_preview(line)
	-- 先关闭可能存在的预览窗口
	if float_win_id and vim.api.nvim_win_is_valid(float_win_id) then
		vim.api.nvim_win_close(float_win_id, true)
		float_win_id = nil
		float_buf_id = nil
	end

	-- 获取整个编辑器尺寸
	-- local editor_width = get_editor_width()
	local editor_height = get_editor_height()

	-- 获取内容的最大宽度，调整浮动窗口宽度
	local preview_width = get_max_line_width(line) + 1

	-- 处理换行
	local wrapped_lines = wrap_line_if_needed(line, preview_width)

	-- 计算所需高度
	local max_height = #wrapped_lines
	if max_height < 1 then
		max_height = 1
	end

	-- 获取当前文件类型
	local filetype = get_current_filetype()

	-- 创建浮动窗口的 buffer
	float_buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, false, wrapped_lines)
	vim.bo[float_buf_id].filetype = filetype

	-- 获取光标在屏幕上的绝对位置
	local cursor_screen_pos = get_cursor_screen_position()
	local screen_row = cursor_screen_pos.row
	local cursor_col = cursor_screen_pos.col

	-- 计算浮动窗口位置（根据光标列对齐）
	local row = screen_row -- 直接覆盖当前行位置
	local col = math.max(cursor_col, 2) -- 根据光标列位置，至少保持2字符的左边距

	-- 确保位置在屏幕范围内
	row = math.max(0, math.min(row, editor_height - max_height - 2))

	-- 自定义高亮组
	vim.cmd([[highlight MyNormal guibg=#2e2e2e guifg=#d1d1d1]]) -- 背景为深灰色，前景为浅灰色
	vim.cmd([[highlight MyFloatBorder guibg=#1e1e1e guifg=#f4a261]]) -- 边框为暗黑色，边框为金色

	-- 打开浮动窗口
	float_win_id = vim.api.nvim_open_win(float_buf_id, false, {
		relative = "editor", -- 相对于整个编辑器
		width = preview_width,
		height = max_height,
		col = col,
		row = row,
		border = "shadow", -- 无边框
		style = "minimal",
		focusable = true,
		mouse = false,
	})

	-- 设置浮动窗口样式（看起来像普通文本）
	vim.api.nvim_set_option_value("winhl", "Normal:Normal", { win = float_win_id })
	vim.api.nvim_set_option_value("number", false, { win = float_win_id })
	vim.api.nvim_set_option_value("relativenumber", false, { win = float_win_id })
	vim.api.nvim_set_option_value("wrap", false, { win = float_win_id })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = float_win_id })

	-- 在浮动窗口中应用这些高亮组
	vim.api.nvim_set_option_value("winhl", "Normal:MyNormal,FloatBorder:MyFloatBorder", { win = float_win_id })

	-- 记录当前预览的行号
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	preview_line_num = cursor_pos[1]

	return float_win_id, float_buf_id
end

-- 关闭浮动窗口
local function close_preview()
	if float_win_id and vim.api.nvim_win_is_valid(float_win_id) then
		vim.api.nvim_win_close(float_win_id, true)
		float_win_id = nil
		float_buf_id = nil
		preview_line_num = nil
	end
end

-- 自动关闭浮动窗口，只在光标移动到不同行时关闭
local function auto_close_preview()
	if preview_line_num then
		local current_line = vim.api.nvim_win_get_cursor(0)[1]
		if current_line ~= preview_line_num then
			close_preview()
		end
	end
end

-- 快捷键触发的处理函数
function M.preview_long_line()
	-- 如果已经打开预览，则关闭
	if float_win_id and vim.api.nvim_win_is_valid(float_win_id) then
		close_preview()
		return
	end

	local line = vim.api.nvim_get_current_line()
	show_preview(line)
end

-- 监听光标移动事件（只在移动到不同行时关闭预览）
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = auto_close_preview,
})

-- 动态适配浮动窗口大小（带防抖）
local resize_timer = nil
vim.api.nvim_create_autocmd("VimResized", {
	callback = function()
		if resize_timer then
			vim.fn.timer_stop(resize_timer)
		end

		resize_timer = vim.fn.timer_start(50, function()
			-- 双重检查：窗口和缓冲区都必须有效
			if
				float_win_id
				and vim.api.nvim_win_is_valid(float_win_id)
				and float_buf_id
				and vim.api.nvim_buf_is_valid(float_buf_id) -- 新增缓冲区有效性检查
			then
				-- 获取当前行内容
				local line = vim.api.nvim_get_current_line()

				-- 重新计算窗口尺寸
				local editor_width = get_editor_width()
				local preview_width = editor_width - 4

				local wrapped_lines = wrap_line_if_needed(line, preview_width)
				local max_height = #wrapped_lines
				if max_height < 1 then
					max_height = 1
				end

				-- 获取光标位置
				local cursor_screen_pos = get_cursor_screen_position()
				local screen_row = cursor_screen_pos.row
				local cursor_col = cursor_screen_pos.col

				-- 更新位置
				local row = screen_row
				local col = math.max(cursor_col, 2)

				-- 安全设置缓冲区内容：添加缓冲区有效性检查
				local success, err = pcall(function()
					-- 先清空缓冲区再添加新内容
					local line_count = vim.api.nvim_buf_line_count(float_buf_id)
					vim.api.nvim_buf_set_lines(float_buf_id, 0, line_count, false, {})
					vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, false, wrapped_lines)
				end)

				if not success then
					vim.notify("更新浮动窗口失败: " .. err, vim.log.levels.WARN)
					close_preview() -- 失败时清理状态
					return
				end

				-- 更新窗口配置
				vim.api.nvim_win_set_config(float_win_id, {
					relative = "editor",
					width = preview_width,
					height = max_height,
					row = row,
					col = col,
				})
			end
			resize_timer = nil
		end)
	end,
})
return M
