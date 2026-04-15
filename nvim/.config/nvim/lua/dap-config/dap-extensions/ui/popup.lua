local M = {}

-- 边框高亮
vim.api.nvim_set_hl(0, "PopupBorderActive", { fg = "#5FAFFF" })
vim.api.nvim_set_hl(0, "PopupBorderInactive", { fg = "#666666" })

local MAX_HEIGHT = 6

-- 存储历史记录的全局表
local history_db = {}

-- 获取字段的历史记录
local function get_history(field_key)
	if not history_db[field_key] then
		history_db[field_key] = {}
	end
	return history_db[field_key]
end

-- 添加历史记录
local function add_to_history(field_key, value)
	if value == nil or value == "" then
		return
	end

	local history = get_history(field_key)
	-- 移除重复的相同记录（如果存在）
	for i, v in ipairs(history) do
		if v == value then
			table.remove(history, i)
			break
		end
	end
	-- 添加到开头
	table.insert(history, 1, value)
	-- 限制历史记录数量（最多100条）
	while #history > 100 do
		table.remove(history)
	end
end

-- 创建子输入框
local function create_input_window(parent, title, width)
	local buf = vim.api.nvim_create_buf(false, true)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "win",
		win = parent,
		row = 1,
		col = 2,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
	})

	-- 设置为空内容
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	vim.bo[buf].omnifunc = "v:lua.vim.lsp.omnifunc"
	vim.bo[buf].filetype = vim.bo.filetype

	return { buf = buf, win = win }
end

local function get_value(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	return table.concat(lines, "\n")
end

function M.open(opts)
	opts = opts or {}
	local fields = opts.fields or error("fields is required")

	local prev_mode = vim.fn.mode()
	local width = 50

	-- 添加关闭标志
	local is_closing = false

	-- 为每个字段维护历史索引和临时存储
	local history_index = {}
	local temp_input = {}

	----------------------------------------------------------------------
	-- 父浮窗（跟随光标）
	----------------------------------------------------------------------
	local parent_buf = vim.api.nvim_create_buf(false, true)
	local parent = vim.api.nvim_open_win(parent_buf, false, {
		relative = "cursor",
		row = 1,
		col = 1,
		width = width + 6,
		height = 12,
		style = "minimal",
		border = "solid",
	})

	----------------------------------------------------------------------
	-- 创建所有字段的输入框
	----------------------------------------------------------------------
	local windows = {}
	for i, field in ipairs(fields) do
		windows[i] = create_input_window(parent, field.label, width)
		-- 初始化历史索引为0（0表示当前输入，没有浏览历史）
		history_index[field.key] = 0
		temp_input[field.key] = "" -- 临时存储当前编辑的内容
	end

	local current_focus_index = 1

	----------------------------------------------------------------------
	-- 更新边框高亮
	----------------------------------------------------------------------
	local function update_borders()
		for i, win in ipairs(windows) do
			local hl = (i == current_focus_index) and "PopupBorderActive" or "PopupBorderInactive"
			vim.api.nvim_win_set_config(win.win, {
				border = {
					{ "╭", hl },
					{ "─", hl },
					{ "╮", hl },
					{ "│", hl },
					{ "╯", hl },
					{ "─", hl },
					{ "╰", hl },
					{ "│", hl },
				},
			})
		end
	end

	----------------------------------------------------------------------
	-- 自动扩展高度
	----------------------------------------------------------------------
	local function resize_window(win_obj)
		local buf = win_obj.buf
		local win = win_obj.win

		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local height = math.min(#lines, MAX_HEIGHT)
		if height < 1 then
			height = 1
		end

		vim.api.nvim_win_set_height(win, height)
	end

	----------------------------------------------------------------------
	-- 自动布局
	----------------------------------------------------------------------
	local function relayout()
		local y = 1

		for _, w in ipairs(windows) do
			vim.api.nvim_win_set_config(w.win, {
				relative = "win",
				win = parent,
				row = y,
				col = 2,
			})

			local h = vim.api.nvim_win_get_height(w.win)
			y = y + h + 2
		end

		vim.api.nvim_win_set_height(parent, y + 1)
	end

	----------------------------------------------------------------------
	-- 保存当前输入到临时存储
	----------------------------------------------------------------------
	local function save_current_input()
		local current_field = fields[current_focus_index]
		if current_field then
			temp_input[current_field.key] = get_value(windows[current_focus_index].buf)
		end
	end

	----------------------------------------------------------------------
	-- 历史记录导航
	----------------------------------------------------------------------
	local function navigate_history(direction)
		if is_closing then
			return
		end

		local current_field = fields[current_focus_index]
		if not current_field then
			return
		end

		local field_key = current_field.key
		local history = get_history(field_key)

		if #history == 0 then
			return
		end

		local current_buf = windows[current_focus_index].buf

		-- 如果当前索引为0（表示在编辑状态），保存当前输入内容
		if history_index[field_key] == 0 then
			save_current_input()
		end

		-- 计算新的索引
		local new_index = history_index[field_key] + direction

		-- 边界检查
		if new_index < 0 then
			new_index = 0
		elseif new_index > #history then
			new_index = #history
		end

		-- 应用历史记录或恢复临时输入
		if new_index == 0 then
			-- 恢复之前保存的临时输入
			local restore_text = temp_input[field_key]
			if restore_text == "" then
				vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, { "" })
			else
				vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, { restore_text })
			end
		else
			-- 显示历史记录
			vim.api.nvim_buf_set_lines(current_buf, 0, -1, false, { history[new_index] })
		end

		history_index[field_key] = new_index

		-- 光标移到行尾
		vim.schedule(function()
			local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
			if #lines > 0 and lines[1] then
				local line_len = #lines[1]
				pcall(vim.api.nvim_win_set_cursor, windows[current_focus_index].win, { 1, line_len })
			end
		end)

		-- 触发调整大小
		resize_window(windows[current_focus_index])
		relayout()
	end

	----------------------------------------------------------------------
	-- 关闭所有浮窗（添加防重复）
	----------------------------------------------------------------------
	local function close_all()
		-- 防止重复关闭
		if is_closing then
			return
		end
		is_closing = true

		-- 暂时禁用所有自动命令，避免递归触发
		vim.schedule(function()
			for _, win in ipairs(windows) do
				if win and win.win and vim.api.nvim_win_is_valid(win.win) then
					pcall(vim.api.nvim_win_close, win.win, true)
				end
			end
			if parent and vim.api.nvim_win_is_valid(parent) then
				pcall(vim.api.nvim_win_close, parent, true)
			end

			if prev_mode == "i" then
				pcall(vim.cmd, "startinsert")
			end

			-- 重置关闭标志
			is_closing = false
		end)
	end

	----------------------------------------------------------------------
	-- 切换焦点
	----------------------------------------------------------------------
	local function focus(i)
		if is_closing then
			return
		end
		-- 切换焦点前保存当前输入
		save_current_input()
		current_focus_index = i
		if windows[i] and windows[i].win and vim.api.nvim_win_is_valid(windows[i].win) then
			pcall(vim.api.nvim_set_current_win, windows[i].win)
			update_borders()
		end
	end

	----------------------------------------------------------------------
	-- 重置当前字段的历史索引（当用户手动编辑时）
	----------------------------------------------------------------------
	local function reset_history_index()
		local current_field = fields[current_focus_index]
		if current_field and history_index[current_field.key] ~= 0 then
			history_index[current_field.key] = 0
			-- 保存当前编辑的内容
			save_current_input()
		end
	end

	----------------------------------------------------------------------
	-- 绑定键位 + 自动扩展事件
	----------------------------------------------------------------------
	for i, w in ipairs(windows) do
		local buf = w.buf
		local field = fields[i]

		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = buf,
			callback = function()
				if not is_closing and vim.api.nvim_win_is_valid(w.win) then
					resize_window(w)
					relayout()
					-- 当用户编辑时，重置历史索引
					reset_history_index()
				end
			end,
		})

		vim.keymap.set({ "n", "i" }, "<Tab>", function()
			focus((current_focus_index % #windows) + 1)
		end, { buffer = buf })

		vim.keymap.set({ "n", "i" }, "<S-Tab>", function()
			focus((current_focus_index - 2) % #windows + 1)
		end, { buffer = buf })

		-- 上下键历史记录（仅在插入模式）
		vim.keymap.set("i", "<Up>", function()
			navigate_history(1)
		end, { buffer = buf })

		vim.keymap.set("i", "<Down>", function()
			navigate_history(-1)
		end, { buffer = buf })

		vim.keymap.set("n", "<Esc>", close_all, { buffer = buf })
		vim.keymap.set("n", "q", close_all, { buffer = buf })

		vim.keymap.set("n", "<CR>", function()
			if is_closing then
				return
			end
			local result = {}
			for j, field in ipairs(fields) do
				local value = get_value(windows[j].buf)
				result[field.key] = value
				-- 保存到历史记录
				add_to_history(field.key, value)
			end

			close_all()

			if opts.on_submit then
				opts.on_submit(result)
			end
		end, { buffer = buf })
	end

	----------------------------------------------------------------------
	-- 默认聚焦第一个输入框
	----------------------------------------------------------------------
	focus(1)
	relayout()
end

return M
