--- @class QuickfixItem
--- @field bufnr number
--- @field module string
--- @field lnum number
--- @field end_lnum number
--- @field col number
--- @field end_col number
--- @field vcol boolean
--- @field pattern any
--- @field text string
--- @field type string
--- @field valid boolean
--- @field user_data any

local QuickfixPreview = {}
QuickfixPreview.__index = QuickfixPreview

function QuickfixPreview:new()
	return setmetatable({
		preview_win_id = nil,
		parsed_buffers = {},
		qf_win_id = nil, -- 记录关联的quickfix/location窗口ID
		is_loclist = false, -- 标记当前是否是location list
	}, self)
end

function QuickfixPreview:is_closed()
	return self.preview_win_id == nil or not vim.api.nvim_win_is_valid(self.preview_win_id)
end

--- @param opts { preview_win_id: number, item_index: number, list: table}
function QuickfixPreview:highlight(opts)
	local curr_item = opts.list[opts.item_index]

	-- 检查是否有效条目
	if not curr_item or curr_item.valid == 0 then
		return
	end

	-- 确保缓冲区有效
	if not vim.api.nvim_buf_is_valid(curr_item.bufnr) then
		return
	end

	if not self.parsed_buffers[curr_item.bufnr] then
		-- 使用安全调用并添加错误处理
		local ok, err = pcall(vim.api.nvim_buf_call, curr_item.bufnr, function()
			vim.cmd("silent! filetype detect")
			pcall(vim.treesitter.start, curr_item.bufnr)
		end)

		if not ok then
			vim.notify("Failed to parse buffer: " .. tostring(err), vim.log.levels.WARN)
		else
			self.parsed_buffers[curr_item.bufnr] = true
		end
	end

	-- 检查光标位置有效性
	local line_count = vim.api.nvim_buf_line_count(curr_item.bufnr)
	local line = math.max(1, math.min(curr_item.lnum, line_count))
	local col = math.max(0, curr_item.col)

	-- 设置预览窗口光标位置
	if vim.api.nvim_win_is_valid(opts.preview_win_id) then
		pcall(vim.api.nvim_win_set_cursor, opts.preview_win_id, { line, col })

		-- 确保预览窗口滚动到正确位置
		local win_height = vim.api.nvim_win_get_height(opts.preview_win_id)
		local scrolloff = math.min(vim.o.scrolloff, math.floor(win_height / 2))
		local target_line = math.max(1, math.min(line, line_count - win_height + 1 + scrolloff))
		pcall(vim.api.nvim_win_set_cursor, opts.preview_win_id, { target_line, col })
		pcall(vim.api.nvim_win_set_cursor, opts.preview_win_id, { line, col })
	end
end

function QuickfixPreview:open()
	-- 判断当前是quickfix还是location list
	local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
	self.is_loclist = win_info and win_info.loclist == 1

	-- 获取对应的列表
	local list = self.is_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()
	if vim.tbl_isempty(list) then
		return
	end

	local curr_line_nr = vim.fn.line(".")
	local curr_item = list[curr_line_nr]

	-- 检查是否有效条目
	if not curr_item or curr_item.valid == 0 then
		return
	end

	-- 确保缓冲区有效
	if not vim.api.nvim_buf_is_valid(curr_item.bufnr) then
		return
	end

	-- 获取当前窗口信息
	local win_height = vim.api.nvim_win_get_height(0)
	local win_width = vim.api.nvim_win_get_width(0)

	-- 计算预览窗口大小 - 使用窗口高度的1.5倍（最大35行）
	local preview_height = math.min(35, math.floor(win_height * 1.5))

	-- 预览窗口始终放在上方
	local preview_row = -preview_height - 2 -- -2 为边框留出空间

	-- 获取文件名并截断过长的标题
	local filename = vim.api.nvim_buf_get_name(curr_item.bufnr)
	local title = vim.fn.fnamemodify(filename, ":t")
	if #title > 40 then
		title = title:sub(1, 37) .. "..."
	end

	-- 创建预览窗口
	local ok, win_id = pcall(vim.api.nvim_open_win, curr_item.bufnr, false, {
		relative = "win",
		win = vim.api.nvim_get_current_win(),
		width = win_width,
		height = preview_height,
		row = preview_row,
		col = 0,
		border = "rounded",
		title = title,
		title_pos = "center",
		focusable = false,
		style = "minimal",
		zindex = 100, -- 确保在其他窗口上方
	})

	if not ok then
		vim.notify("Failed to open preview window: " .. tostring(win_id), vim.log.levels.ERROR)
		return
	end

	self.preview_win_id = win_id
	self.qf_win_id = vim.api.nvim_get_current_win() -- 记录当前窗口ID

	-- 设置窗口选项
	vim.wo[self.preview_win_id].relativenumber = false
	vim.wo[self.preview_win_id].number = true
	vim.wo[self.preview_win_id].winblend = 10 -- 增加透明度
	vim.wo[self.preview_win_id].cursorline = true
	vim.wo[self.preview_win_id].wrap = false -- 防止长行影响布局
	vim.wo[self.preview_win_id].signcolumn = "no" -- 不显示标记列
	vim.wo[self.preview_win_id].foldenable = false -- 禁用折叠

	self:highlight({
		preview_win_id = self.preview_win_id,
		item_index = curr_line_nr,
		list = list,
	})

	return true
end

function QuickfixPreview:close()
	if self:is_closed() then
		return
	end

	pcall(vim.api.nvim_win_close, self.preview_win_id, true)
	self.preview_win_id = nil
	self.qf_win_id = nil
end

function QuickfixPreview:refresh()
	-- 检查当前窗口是否是quickfix或location list窗口
	if vim.bo.filetype ~= "qf" then
		self:close()
		return
	end

	-- 如果预览已关闭，尝试打开
	if self:is_closed() then
		self:open()
		return
	end

	-- 判断当前是quickfix还是location list
	local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
	local is_loclist = win_info and win_info.loclist == 1

	-- 如果列表类型变化，需要重新打开预览
	if self.is_loclist ~= is_loclist then
		self:close()
		self:open()
		return
	end

	-- 获取对应的列表
	local list = is_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()
	local curr_line_nr = vim.fn.line(".")
	local curr_item = list[curr_line_nr]

	-- 检查是否有效条目
	if not curr_item or curr_item.valid == 0 then
		self:close()
		return
	end

	-- 确保预览窗口仍然有效
	if not vim.api.nvim_win_is_valid(self.preview_win_id) then
		self.preview_win_id = nil
		self:open()
		return
	end

	-- 仅当缓冲区变化时切换缓冲区
	local current_buf = vim.api.nvim_win_get_buf(self.preview_win_id)
	if current_buf ~= curr_item.bufnr then
		if vim.api.nvim_buf_is_valid(curr_item.bufnr) then
			vim.api.nvim_win_set_buf(self.preview_win_id, curr_item.bufnr)

			-- 更新窗口标题
			local filename = vim.api.nvim_buf_get_name(curr_item.bufnr)
			local title = vim.fn.fnamemodify(filename, ":t")
			vim.api.nvim_win_set_config(self.preview_win_id, {
				title = #title > 40 and title:sub(1, 37) .. "..." or title,
				title_pos = "center",
			})
		else
			self:close()
			return
		end
	end

	self:highlight({
		preview_win_id = self.preview_win_id,
		item_index = curr_line_nr,
		list = list,
	})
end

local qf_preview = QuickfixPreview:new()

-- 当进入quickfix或location list窗口时打开预览
vim.api.nvim_create_autocmd("WinEnter", {
	callback = function()
		if vim.bo.filetype == "qf" then
			qf_preview:refresh()
		end
	end,
	pattern = "*",
})

-- 优化自动命令：使用窗口ID
vim.api.nvim_create_autocmd("WinClosed", {
	callback = function(args)
		local closed_win_id = tonumber(args.match)
		if closed_win_id == qf_preview.qf_win_id then
			qf_preview:close()
		end
	end,
	pattern = "*",
})

-- 添加去抖动防止频繁刷新
local refresh_timer = nil
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	callback = function()
		if vim.bo.filetype ~= "qf" then
			return
		end

		-- 确保处理的是正确的窗口
		if qf_preview.qf_win_id and vim.api.nvim_get_current_win() ~= qf_preview.qf_win_id then
			return
		end

		-- 去抖动处理 (50ms)
		if refresh_timer then
			refresh_timer:stop()
		end

		refresh_timer = vim.defer_fn(function()
			qf_preview:refresh()
		end, 50)
	end,
	pattern = "*",
})

-- 离开窗口时关闭预览
vim.api.nvim_create_autocmd("WinLeave", {
	callback = function(args)
		if vim.bo.filetype == "qf" then
			qf_preview:close()
		end
	end,
	pattern = "*",
})

-- 添加退出时清理
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		qf_preview:close()
	end,
})

-- ✨ 删除 quickfix / loclist 条目工具函数
local function delete_qf_items()
	-- 获取当前窗口信息以区分 quickfix 和 location list
	local win_id = vim.api.nvim_get_current_win()
	local win_info = vim.fn.getwininfo(win_id)[1]

	-- 修复：正确判断 location list
	local is_loc = win_info and win_info.loclist == 1
	local is_qf = win_info and win_info.quickfix == 1 and not is_loc

	-- 获取对应的列表
	local qflist
	if is_qf then
		qflist = vim.fn.getqflist()
	elseif is_loc then
		qflist = vim.fn.getloclist(0)
	else
		return
	end

	if not qflist or #qflist == 0 then
		return
	end

	local mode = vim.api.nvim_get_mode().mode
	local start_idx, count
	if mode == "n" then
		start_idx = vim.fn.line(".")
		count = vim.v.count > 0 and vim.v.count or 1
	else
		local v_start_idx = vim.fn.line("v")
		local v_end_idx = vim.fn.line(".")
		start_idx = math.min(v_start_idx, v_end_idx)
		count = math.abs(v_end_idx - v_start_idx) + 1
		vim.cmd("normal! <esc>")
	end

	if start_idx < 1 or start_idx > #qflist then
		return
	end

	-- 创建要删除的索引列表（从后往前删除避免索引变化）
	local indices_to_remove = {}
	for i = start_idx, math.min(start_idx + count - 1, #qflist) do
		table.insert(indices_to_remove, i)
	end

	-- 从后往前删除
	table.sort(indices_to_remove, function(a, b)
		return a > b
	end)
	for _, idx in ipairs(indices_to_remove) do
		table.remove(qflist, idx)
	end

	-- 更新列表
	if is_qf then
		vim.fn.setqflist(qflist, "r")
	elseif is_loc then
		vim.fn.setloclist(0, qflist, "r")
	end

	-- 定位到合适位置
	local new_pos = math.min(start_idx, #qflist)
	if new_pos > 0 then
		vim.fn.cursor(new_pos, 1)
	end
end

-- ✨ Quickfix/Location list 窗口定制
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
	pattern = "qf",
	desc = "Quickfix and location list tweaks",
	callback = function()
		local win_id = vim.api.nvim_get_current_win()
		local win_info = vim.fn.getwininfo(win_id)[1]

		-- 确定是 quickfix 还是 location list
		local is_loc = win_info and win_info.loclist == 1
		local is_qf = win_info and win_info.quickfix == 1 and not is_loc

		-- 设置不显示在缓冲区列表
		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

		-- 设置关闭命令（根据窗口类型）
		local close_cmd = is_qf and "<CMD>cclose<CR>" or "<CMD>lclose<CR>"

		-- 设置删除映射
		vim.keymap.set("n", "<ESC>", close_cmd, { buffer = true, silent = true })
		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true, desc = "Delete current item" })
		vim.keymap.set("x", "d", delete_qf_items, { buffer = true, desc = "Delete selected items" })

		-- 添加更多实用映射
		vim.keymap.set("n", "q", close_cmd, { buffer = true, silent = true })

		-- 添加列表特定导航
		if is_qf then
			vim.keymap.set("n", "L", "<CMD>cnext<CR>", { buffer = true, desc = "Next quickfix item" })
			vim.keymap.set("n", "H", "<CMD>cprev<CR>", { buffer = true, desc = "Previous quickfix item" })
		elseif is_loc then
			vim.keymap.set("n", "L", "<CMD>lnext<CR>", { buffer = true, desc = "Next location item" })
			vim.keymap.set("n", "H", "<CMD>lprev<CR>", { buffer = true, desc = "Previous location item" })
		end

		-- 添加状态行提示
		local list_type = is_qf and "Quickfix" or "Location List"
		vim.opt_local.statusline = list_type .. " %<%f %=%-14.(%l/%L%)%P"
	end,
})
