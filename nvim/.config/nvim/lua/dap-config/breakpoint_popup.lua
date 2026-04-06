local M = {}

-- 边框高亮
vim.api.nvim_set_hl(0, "PopupBorderActive", { fg = "#5FAFFF" })
vim.api.nvim_set_hl(0, "PopupBorderInactive", { fg = "#666666" })

local MAX_HEIGHT = 6

-- 创建子输入框（不再传 row，row 由 relayout 控制）
local function create_input_window(parent, title, width)
	local buf = vim.api.nvim_create_buf(false, true)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "win",
		win = parent,
		row = 1, -- ⭐ 固定为 1，布局完全交给 relayout()
		col = 2,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })

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
	end

	local index = 1

	----------------------------------------------------------------------
	-- 更新边框高亮
	----------------------------------------------------------------------
	local function update_borders()
		for i, win in ipairs(windows) do
			local hl = (i == index) and "PopupBorderActive" or "PopupBorderInactive"
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
	-- ⭐ 自动布局（解决重叠的关键）
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
	-- 关闭所有浮窗
	----------------------------------------------------------------------
	local function close_all()
		for _, win in ipairs(windows) do
			if vim.api.nvim_win_is_valid(win.win) then
				vim.api.nvim_win_close(win.win, true)
			end
		end
		if vim.api.nvim_win_is_valid(parent) then
			vim.api.nvim_win_close(parent, true)
		end

		if prev_mode == "i" then
			vim.cmd("startinsert")
		end
	end

	----------------------------------------------------------------------
	-- 切换焦点
	----------------------------------------------------------------------
	local function focus(i)
		index = i
		vim.api.nvim_set_current_win(windows[i].win)
		update_borders()
	end

	----------------------------------------------------------------------
	-- 绑定键位 + 自动扩展事件
	----------------------------------------------------------------------
	for i, w in ipairs(windows) do
		local buf = w.buf

		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = buf,
			callback = function()
				resize_window(w)
				relayout()
			end,
		})

		vim.keymap.set({ "n", "i" }, "<Tab>", function()
			focus((index % #windows) + 1)
		end, { buffer = buf })

		vim.keymap.set({ "n", "i" }, "<S-Tab>", function()
			focus((index - 2) % #windows + 1)
		end, { buffer = buf })

		vim.keymap.set("n", "<Esc>", close_all, { buffer = buf })
		vim.keymap.set("n", "q", close_all, { buffer = buf })

		vim.keymap.set("n", "<CR>", function()
			local result = {}
			for j, field in ipairs(fields) do
				result[field.key] = get_value(windows[j].buf)
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
