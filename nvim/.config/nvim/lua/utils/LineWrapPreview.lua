local M = {}

-- 存储当前的浮动窗口 ID 和缓冲区 ID
local float_win_id, float_buf_id, preview_line_num = nil, nil, nil

-- 获取当前 buffer 的 filetype
local function get_current_filetype()
	return vim.bo.filetype
end

-- 获取编辑器的宽度和高度
local function get_editor_dimensions()
	return vim.o.columns, vim.o.lines
end

-- 修复：兼容不同版本的窗口位置获取
local function get_cursor_screen_position()
	local winid = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_position(winid)
	local cursor_pos = vim.api.nvim_win_get_cursor(winid)
	local win_topline = vim.fn.line("w0", winid) -- 窗口顶部行号

	-- 计算光标在屏幕上的绝对行位置
	local screen_row = pos[1] + (cursor_pos[1] - win_topline)
	return { row = screen_row, col = pos[2] + cursor_pos[2] }
end

-- 改进的自动换行函数
local function wrap_line_if_needed(line, width)
	if #line <= width then
		return { line }
	end

	local wrapped_lines, start_index = {}, 1
	while start_index <= #line do
		local segment = line:sub(start_index, start_index + width - 1)
		local last_space = segment:match("%s[^\r\n]*$")
		local end_index = last_space and (start_index + last_space:len() - 1) or (start_index + width - 1)
		table.insert(wrapped_lines, line:sub(start_index, end_index))
		start_index = end_index + 1
	end
	return wrapped_lines
end

-- 获取当前行内容的最大宽度（根据内容自适应宽度）
local function get_max_line_width(line)
	if #line == 0 then
		return 1
	end
	local wrapped_lines = wrap_line_if_needed(line, get_editor_dimensions() - 4)
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
		float_win_id, float_buf_id = nil, nil
	end

	-- 获取内容的最大宽度，调整浮动窗口宽度
	local preview_width = get_max_line_width(line) + 1
	local wrapped_lines = wrap_line_if_needed(line, preview_width)
	local max_height = math.max(#wrapped_lines, 1)
	local filetype = get_current_filetype()

	-- 创建浮动窗口的 buffer
	float_buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, false, wrapped_lines)
	vim.bo[float_buf_id].filetype = filetype

	-- 获取光标在屏幕上的绝对位置
	local cursor_screen_pos = get_cursor_screen_position()
	local screen_row, cursor_col = cursor_screen_pos.row, cursor_screen_pos.col

	-- 计算浮动窗口位置（根据光标列对齐）
	local row, col =
		math.max(0, math.min(screen_row, get_editor_dimensions() - max_height - 2)), math.max(cursor_col, 2)

	-- 自定义高亮组
	vim.cmd([[highlight MyNormal guibg=#2e2e2e guifg=#d1d1d1]])
	vim.cmd([[highlight MyFloatBorder guibg=#1e1e1e guifg=#f4a261]])

	-- 打开浮动窗口
	float_win_id = vim.api.nvim_open_win(float_buf_id, false, {
		relative = "editor",
		width = preview_width,
		height = max_height,
		col = col,
		row = row,
		border = "shadow",
		style = "minimal",
		focusable = true,
		mouse = false,
	})

	-- 设置浮动窗口样式
	vim.api.nvim_set_option_value("winhl", "Normal:MyNormal,FloatBorder:MyFloatBorder", { win = float_win_id })
	vim.api.nvim_set_option_value("wrap", false, { win = float_win_id })
	vim.api.nvim_set_option_value("signcolumn", "no", { win = float_win_id })

	-- 记录当前预览的行号
	preview_line_num = vim.api.nvim_win_get_cursor(0)[1]
end

-- 关闭浮动窗口
local function close_preview()
	if float_win_id and vim.api.nvim_win_is_valid(float_win_id) then
		vim.api.nvim_win_close(float_win_id, true)
		float_win_id, float_buf_id, preview_line_num = nil, nil, nil
	end
end

-- 自动关闭浮动窗口，只在光标移动到不同行时关闭
local function auto_close_preview()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	if preview_line_num and current_line ~= preview_line_num then
		close_preview()
	end
end

-- 快捷键触发的处理函数
function M.preview_long_line()
	if float_win_id and vim.api.nvim_win_is_valid(float_win_id) then
		close_preview()
		return
	end
	show_preview(vim.api.nvim_get_current_line())
end

-- 判断当前行内容长度是否超过当前窗口宽度
function M.auto_preview_long_line()
	local line = vim.api.nvim_get_current_line()
	local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
	if #line > current_win_width then
		M.preview_long_line()
	end
end

-- 监听光标移动事件（鼠标和键盘都能触发）
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = function()
		M.auto_preview_long_line()
		auto_close_preview()
	end,
})

-- 动态适配浮动窗口大小（带防抖）
vim.api.nvim_create_autocmd("VimResized", {
	callback = function()
		vim.defer_fn(function()
			if
				float_win_id
				and vim.api.nvim_win_is_valid(float_win_id)
				and float_buf_id
				and vim.api.nvim_buf_is_valid(float_buf_id)
			then
				local line = vim.api.nvim_get_current_line()
				local wrapped_lines = wrap_line_if_needed(line, get_editor_dimensions() - 4)
				local max_height = math.max(#wrapped_lines, 1)

				local cursor_screen_pos = get_cursor_screen_position()
				local screen_row, cursor_col = cursor_screen_pos.row, cursor_screen_pos.col

				local row, col =
					math.max(0, math.min(screen_row, get_editor_dimensions() - max_height - 2)), math.max(cursor_col, 2)

				-- 更新浮动窗口
				vim.api.nvim_win_set_config(float_win_id, {
					relative = "editor",
					width = get_max_line_width(line) + 1,
					height = max_height,
					row = row,
					col = col,
				})

				-- 更新缓冲区内容
				vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, false, wrapped_lines)
			end
		end, 50)
	end,
})

return M
