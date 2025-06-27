local M = {}

-- 存储当前的浮动窗口 ID 和缓冲区 ID
local float_win_id, float_buf_id, preview_line_num = nil, nil, nil

-- 获取当前 buffer 的 filetype (先定义)
local function get_current_filetype()
	return vim.bo.filetype
end

-- 获取实际视觉内容（忽略行首空白）
local function get_visual_content(line)
	return line:match("^%s*(.+)") or ""
end

-- 获取编辑器的宽度和高度（整个工作区）
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

-- 智能换行（按单词分割）
local function smart_wrap(content, width)
	if #content == 0 then
		return { "" }
	end

	if #content <= width then
		return { content }
	end

	local lines = {}
	local current_line = ""

	-- 按单词分割内容
	for word in content:gmatch("%S+") do
		local word_len = #word
		local current_len = #current_line

		-- 如果当前行非空，添加单词时需要加一个空格
		local add_len = current_len > 0 and word_len + 1 or word_len

		if current_len + add_len <= width then
			current_line = current_line .. (current_len > 0 and " " or "") .. word
		else
			if current_len > 0 then
				table.insert(lines, current_line)
			end
			current_line = word
		end
	end

	if #current_line > 0 then
		table.insert(lines, current_line)
	end

	return lines
end

-- 计算最大行宽度（基于视觉内容）
local function get_max_line_width(content)
	if #content == 0 then
		return 1
	end

	-- 使用整个编辑器宽度作为换行参考
	local editor_width = get_editor_dimensions()
	local wrap_width = math.max(editor_width - 4, 20) -- 最小宽度20
	local wrapped_lines = smart_wrap(content, wrap_width)

	local max_width = 0
	for _, l in ipairs(wrapped_lines) do
		-- 使用显示宽度（正确处理制表符等特殊字符）
		max_width = math.max(max_width, vim.fn.strdisplaywidth(l))
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

	-- 获取实际视觉内容（忽略行首空白）
	local visual_content = get_visual_content(line)
	if visual_content == "" then
		return
	end -- 空内容不显示预览

	-- 获取内容的最大宽度，调整浮动窗口宽度（基于整个编辑器宽度）
	local preview_width = get_max_line_width(visual_content)
	local editor_width = get_editor_dimensions()
	preview_width = math.min(preview_width, editor_width - 4) -- 不超过编辑器宽度

	-- 使用整个编辑器宽度作为换行参考
	local wrapped_lines = smart_wrap(visual_content, editor_width - 4)
	local max_height = math.max(#wrapped_lines, 1)

	-- 使用之前定义的 get_current_filetype
	local filetype = get_current_filetype()

	-- 创建浮动窗口的 buffer
	float_buf_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(float_buf_id, 0, -1, false, wrapped_lines)
	vim.bo[float_buf_id].filetype = filetype

	-- 获取光标在屏幕上的绝对位置
	local cursor_screen_pos = get_cursor_screen_position()
	local screen_row, cursor_col = cursor_screen_pos.row, cursor_screen_pos.col

	-- 计算浮动窗口位置（根据光标列对齐）
	local row = math.max(0, math.min(screen_row, get_editor_dimensions() - max_height - 2))
	local col = math.max(cursor_col, 2)

	-- 确保窗口不会超出屏幕右侧
	col = math.min(col, editor_width - preview_width - 1)

	-- 自定义高亮组
	vim.cmd([[highlight MyNormal guibg=#2e2e2e guifg=#d1d1d1]])
	vim.cmd([[highlight MyFloatBorder guibg=#1e1e1e guifg=#f4a261]])

	-- 打开浮动窗口（基于整个编辑器）
	float_win_id = vim.api.nvim_open_win(float_buf_id, false, {
		relative = "editor", -- 相对于整个编辑器
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

	-- 获取实际视觉内容（忽略行首空白）
	local visual_content = get_visual_content(vim.api.nvim_get_current_line())
	if visual_content ~= "" then
		show_preview(visual_content)
	end
end

-- 判断当前行内容长度是否超过当前窗口宽度
function M.auto_preview_long_line()
	local line = vim.api.nvim_get_current_line()
	local visual_content = get_visual_content(line)
	if visual_content == "" then
		return
	end
	-- 使用整个编辑器宽度作为判断基准
	local editor_width = vim.api.nvim_win_get_width(0)
	if #visual_content > editor_width then
		M.preview_long_line()
	end
	-- 监听光标移动事件（鼠标和键盘都能触发）
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		callback = function()
			M.auto_preview_long_line()
			auto_close_preview()
		end,
	})
end

-- 监听光标移动事件（鼠标和键盘都能触发）
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = function()
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
				-- 获取实际视觉内容（忽略行首空白）
				local visual_content = get_visual_content(vim.api.nvim_get_current_line())
				if visual_content == "" then
					close_preview()
					return
				end

				-- 使用整个编辑器宽度作为换行参考
				local editor_width = get_editor_dimensions()
				local wrapped_lines = smart_wrap(visual_content, editor_width - 4)
				local max_height = math.max(#wrapped_lines, 1)

				local cursor_screen_pos = get_cursor_screen_position()
				local screen_row, cursor_col = cursor_screen_pos.row, cursor_screen_pos.col

				local row = math.max(0, math.min(screen_row, editor_width - max_height - 2))
				local col = math.max(cursor_col, 2)
				col = math.min(col, editor_width - get_max_line_width(visual_content) - 2)

				-- 更新浮动窗口
				vim.api.nvim_win_set_config(float_win_id, {
					relative = "editor",
					width = get_max_line_width(visual_content) + 1,
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
