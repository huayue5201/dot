local QuickfixPreview = {}
QuickfixPreview.__index = QuickfixPreview

function QuickfixPreview:new()
	return setmetatable({
		preview_win_id = nil,
		parsed_buffers = {},
		qf_win_id = nil,
		is_loclist = false,
		last_position = nil,
		last_win_pos = nil, -- 记录窗口屏幕位置
	}, self)
end

function QuickfixPreview:is_closed()
	return self.preview_win_id == nil or not vim.api.nvim_win_is_valid(self.preview_win_id)
end

--- @param opts { preview_win_id: number, item_index: number, list: table}
function QuickfixPreview:highlight(opts)
	local curr_item = opts.list[opts.item_index]
	if not curr_item or curr_item.valid == 0 then
		return
	end

	-- 确保缓冲区有效且已加载
	if not vim.api.nvim_buf_is_valid(curr_item.bufnr) then
		return
	end

	-- 确保缓冲区已加载
	if not vim.api.nvim_buf_is_loaded(curr_item.bufnr) then
		vim.fn.bufload(curr_item.bufnr)
	end

	-- 检查行号是否在有效范围内
	local line_count = vim.api.nvim_buf_line_count(curr_item.bufnr)
	if line_count == 0 then
		return
	end

	-- 确保行号有效
	local line = math.max(1, math.min(curr_item.lnum, line_count))
	local col = math.max(0, curr_item.col or 0) -- 确保列号存在

	if not self.parsed_buffers[curr_item.bufnr] then
		local function safe_parse()
			-- 检查 treesitter 是否可用
			local has_treesitter, _ = pcall(require, "nvim-treesitter")
			if not has_treesitter then
				return
			end

			-- 检测文件类型
			vim.cmd("silent! filetype detect")

			-- 安全启用 Treesitter
			if not vim.treesitter.highlighter.active[curr_item.bufnr] then
				-- 使用 protected call 防止 treesitter 崩溃
				local ok, err = pcall(vim.treesitter.start, curr_item.bufnr)
				if not ok then
					vim.notify("Treesitter failed to start: " .. tostring(err), vim.log.levels.WARN)
				end
			end
		end

		-- 使用安全调用
		local ok, err = pcall(vim.api.nvim_buf_call, curr_item.bufnr, safe_parse)
		if not ok then
			vim.notify("Failed to parse buffer: " .. tostring(err), vim.log.levels.WARN)
		else
			self.parsed_buffers[curr_item.bufnr] = true
		end
	end

	-- 设置光标位置
	if vim.api.nvim_win_is_valid(opts.preview_win_id) then
		pcall(function()
			vim.api.nvim_win_set_cursor(opts.preview_win_id, { line, col })

			-- 确保位置在可视区域内
			local win_height = vim.api.nvim_win_get_height(opts.preview_win_id)
			local scrolloff = math.min(vim.o.scrolloff, math.floor(win_height / 2))
			local target_line = math.max(1, math.min(line, line_count - win_height + 1 + scrolloff))

			local current_line = vim.api.nvim_win_get_cursor(opts.preview_win_id)[1]
			if math.abs(current_line - target_line) > win_height / 2 then
				vim.api.nvim_win_set_cursor(opts.preview_win_id, { target_line, col })
			end

			vim.api.nvim_win_set_cursor(opts.preview_win_id, { line, col })
		end)
	end
end

--- 计算最佳预览窗口位置
--- @return table {relative: string, row: number, col: number, width: number, height: number, use_footer: boolean}
function QuickfixPreview:calculate_position()
	local win_id = vim.api.nvim_get_current_win()
	local win_height = vim.api.nvim_win_get_height(win_id)
	local win_width = vim.api.nvim_win_get_width(win_id)

	local preview_height = math.min(35, math.floor(win_height * 1.5))
	local preview_width = win_width

	local screen_width = vim.o.columns
	local screen_height = vim.o.lines

	local win_screen_pos = vim.fn.win_screenpos(win_id)
	local win_top = win_screen_pos[1]
	local win_left = win_screen_pos[2]
	local win_bottom = win_top + win_height - 1
	local win_right = win_left + win_width - 1

	local space_above = win_top - 1
	local space_below = screen_height - win_bottom
	local space_left = win_left - 1
	local space_right = screen_width - win_right

	local relative_pos = "win"
	local row = -preview_height - 2
	local col = 0
	local use_footer = false

	if space_above < preview_height and space_below >= preview_height then
		row = win_height
		use_footer = false
	elseif space_below < preview_height and space_above >= preview_height then
		row = -preview_height - 2
		use_footer = true
	elseif space_left > space_right and space_left > win_width then
		relative_pos = "win"
		row = 0
		col = -win_width - 2
		preview_width = math.min(win_width * 2, space_left - 2)
		use_footer = false
	elseif space_right > space_left and space_right > win_width then
		relative_pos = "win"
		row = 0
		col = win_width
		preview_width = math.min(win_width * 2, space_right - 2)
		use_footer = false
	elseif space_above >= preview_height then
		row = -preview_height - 2
		use_footer = true
	else
		row = win_height
		use_footer = false
	end

	return {
		relative = relative_pos,
		row = row,
		col = col,
		width = preview_width,
		height = preview_height,
		use_footer = use_footer,
	}
end

function QuickfixPreview:open()
	local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
	self.is_loclist = win_info and win_info.loclist == 1

	local list = self.is_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()
	if vim.tbl_isempty(list) then
		return
	end

	local curr_line_nr = vim.fn.line(".")
	local curr_item = list[curr_line_nr]

	if not curr_item or curr_item.valid == 0 then
		return
	end

	if not vim.api.nvim_buf_is_valid(curr_item.bufnr) then
		return
	end

	local position = self:calculate_position()
	self.last_position = position
	-- 记录当前窗口位置
	self.last_win_pos = vim.fn.win_screenpos(vim.api.nvim_get_current_win())

	local filename = vim.api.nvim_buf_get_name(curr_item.bufnr)
	local title = vim.fn.fnamemodify(filename, ":t")
	if #title > 40 then
		title = title:sub(1, 37) .. "..."
	end

	local title_text = ""
	local footer_text = ""

	if position.use_footer then
		title_text = " " .. "  " .. title .. " "
	else
		footer_text = " " .. "  " .. title .. " "
	end

	local win_config = {
		relative = position.relative,
		win = vim.api.nvim_get_current_win(),
		width = position.width,
		height = position.height,
		row = position.row,
		col = position.col,
		border = "rounded",
		title = title_text,
		title_pos = "center",
		footer = footer_text,
		footer_pos = "center",
		focusable = false,
		style = "minimal",
		zindex = 100,
		mouse = false,
	}

	local ok, win_id = pcall(vim.api.nvim_open_win, curr_item.bufnr, false, win_config)

	if not ok then
		vim.notify("Failed to open preview window: " .. tostring(win_id), vim.log.levels.ERROR)
		return
	end

	self.preview_win_id = win_id
	self.qf_win_id = vim.api.nvim_get_current_win()

	vim.wo[self.preview_win_id].relativenumber = false
	vim.wo[self.preview_win_id].number = true
	vim.wo[self.preview_win_id].winblend = 10
	vim.wo[self.preview_win_id].cursorline = true
	vim.wo[self.preview_win_id].wrap = false
	vim.wo[self.preview_win_id].signcolumn = "no"
	vim.wo[self.preview_win_id].foldenable = false

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
	self.last_position = nil
	self.last_win_pos = nil
end

--- 检查位置是否发生变化
--- @return boolean
function QuickfixPreview:position_changed()
	if not self.last_position then
		return true
	end

	local new_position = self:calculate_position()
	-- 获取当前窗口位置
	local curr_win_pos = vim.fn.win_screenpos(vim.api.nvim_get_current_win())
	local last_win_pos = self.last_win_pos or { 0, 0 }

	-- 比较所有关键参数
	return new_position.row ~= self.last_position.row
		or new_position.col ~= self.last_position.col
		or new_position.width ~= self.last_position.width
		or new_position.height ~= self.last_position.height
		or curr_win_pos[1] ~= last_win_pos[1] -- 窗口顶部位置变化
		or curr_win_pos[2] ~= last_win_pos[2] -- 窗口左侧位置变化
end

function QuickfixPreview:refresh()
	if vim.bo.filetype ~= "qf" then
		self:close()
		return
	end

	-- 更新当前窗口位置记录
	self.last_win_pos = vim.fn.win_screenpos(vim.api.nvim_get_current_win())

	if self:is_closed() then
		self:open()
		return
	end

	local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
	local is_loclist = win_info and win_info.loclist == 1

	if self.is_loclist ~= is_loclist then
		self:close()
		self:open()
		return
	end

	if self:position_changed() then
		self:close()
		self:open()
		return
	end

	local list = is_loclist and vim.fn.getloclist(0) or vim.fn.getqflist()
	local curr_line_nr = vim.fn.line(".")
	local curr_item = list[curr_line_nr]

	if not curr_item or curr_item.valid == 0 then
		self:close()
		return
	end

	if not vim.api.nvim_win_is_valid(self.preview_win_id) then
		self.preview_win_id = nil
		self:open()
		return
	end

	local current_buf = vim.api.nvim_win_get_buf(self.preview_win_id)
	if current_buf ~= curr_item.bufnr then
		if vim.api.nvim_buf_is_valid(curr_item.bufnr) then
			vim.api.nvim_win_set_buf(self.preview_win_id, curr_item.bufnr)

			local filename = vim.api.nvim_buf_get_name(curr_item.bufnr)
			local title = vim.fn.fnamemodify(filename, ":t")
			if #title > 40 then
				title = title:sub(1, 37) .. "..."
			end

			local icon = " "
			if self.last_position.row < 0 then
				icon = " "
			elseif self.last_position.row > 0 then
				icon = " "
			elseif self.last_position.col < 0 then
				icon = " "
			elseif self.last_position.col > 0 then
				icon = " "
			end

			local config_update = {}
			if self.last_position.use_footer then
				config_update.footer = " " .. icon .. title .. " "
			else
				config_update.title = " " .. icon .. title .. " "
			end

			vim.api.nvim_win_set_config(self.preview_win_id, config_update)
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

-- 使用更合适的事件组合
vim.api.nvim_create_autocmd("WinEnter", {
	callback = function()
		if vim.bo.filetype == "qf" then
			-- 添加延迟确保窗口位置更新完成
			vim.defer_fn(function()
				qf_preview:refresh()
			end, 10)
		end
	end,
	pattern = "*",
})

-- 使用WinClosed事件处理窗口关闭
vim.api.nvim_create_autocmd("WinClosed", {
	callback = function(args)
		local closed_win_id = tonumber(args.match)
		if closed_win_id == qf_preview.qf_win_id then
			qf_preview:close()
		end
	end,
	pattern = "*",
})

-- 优化事件监听：使用最相关的事件
vim.api.nvim_create_autocmd({
	"CursorMoved",
	"CursorMovedI",
	"WinScrolled", -- 窗口滚动时更新
	"WinResized", -- 窗口大小改变时更新
	"ModeChanged", -- 模式改变时更新
}, {
	callback = function()
		if vim.bo.filetype ~= "qf" then
			return
		end

		if qf_preview.qf_win_id and vim.api.nvim_get_current_win() ~= qf_preview.qf_win_id then
			return
		end

		-- 立即刷新
		qf_preview:refresh()
	end,
	pattern = "*",
})

-- 使用WinLeave事件关闭预览
vim.api.nvim_create_autocmd("WinLeave", {
	callback = function()
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
	local win_id = vim.api.nvim_get_current_win()
	local win_info = vim.fn.getwininfo(win_id)[1]

	local is_loc = win_info and win_info.loclist == 1
	local is_qf = win_info and win_info.quickfix == 1 and not is_loc

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

	local indices_to_remove = {}
	for i = start_idx, math.min(start_idx + count - 1, #qflist) do
		table.insert(indices_to_remove, i)
	end

	table.sort(indices_to_remove, function(a, b)
		return a > b
	end)
	for _, idx in ipairs(indices_to_remove) do
		table.remove(qflist, idx)
	end

	if is_qf then
		vim.fn.setqflist(qflist, "r")
	elseif is_loc then
		vim.fn.setloclist(0, qflist, "r")
	end

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

		local is_loc = win_info and win_info.loclist == 1
		local is_qf = win_info and win_info.quickfix == 1 and not is_loc

		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

		local close_cmd = is_qf and "<CMD>cclose<CR>" or "<CMD>lclose<CR>"

		vim.keymap.set("n", "<ESC>", close_cmd, { buffer = true, silent = true })
		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true, desc = "Delete current item" })
		vim.keymap.set("x", "d", delete_qf_items, { buffer = true, desc = "Delete selected items" })

		vim.keymap.set("n", "q", close_cmd, { buffer = true, silent = true })

		if is_qf then
			vim.keymap.set("n", "L", "<CMD>cnext<CR>", { buffer = true, desc = "Next quickfix item" })
			vim.keymap.set("n", "H", "<CMD>cprev<CR>", { buffer = true, desc = "Previous quickfix item" })
		elseif is_loc then
			vim.keymap.set("n", "L", "<CMD>lnext<CR>", { buffer = true, desc = "Next location item" })
			vim.keymap.set("n", "H", "<CMD>lprev<CR>", { buffer = true, desc = "Previous location item" })
		end

		local list_type = is_qf and "Quickfix" or "Location List"
		vim.opt_local.statusline = list_type .. " %<%f %=%-14.(%l/%L%)%P"
	end,
})

-- quickfixtextfunc
require("config.quickfixtext").setup()
