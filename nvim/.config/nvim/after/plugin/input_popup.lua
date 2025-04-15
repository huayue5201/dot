local M = {}

local existing_window, existing_buffer
local input_history = {}
local hist_index = 0

-- 禁用的 buftype 和 filetype
local disabled_types = {
	buftype = {
		"nofile",
		"prompt",
		"quickfix",
		"terminal",
		"help",
	},
	filetype = {
		"dap-repl",
		"TelescopePrompt",
		"NvimTree",
		"neo-tree",
	},
}

local function is_disabled()
	local buftype = vim.bo.buftype
	local filetype = vim.bo.filetype
	return vim.tbl_contains(disabled_types.buftype, buftype) or vim.tbl_contains(disabled_types.filetype, filetype)
end

local function under_cursor(input_width)
	return {
		relative = "cursor",
		row = 1,
		col = 0,
		width = input_width + 2,
		height = 1,
	}
end

local function close_window(window, buffer, on_confirm)
	vim.cmd("stopinsert")
	if window and vim.api.nvim_win_is_valid(window) then
		pcall(vim.api.nvim_win_close, window, true)
	end
	if buffer and vim.api.nvim_buf_is_valid(buffer) then
		pcall(vim.api.nvim_buf_delete, buffer, { force = true })
	end
	on_confirm(nil)
end

-- 浮动输入函数
---@param opts table
---@param on_confirm fun(input: string|nil)
---@param win_config table|nil
function M.input(opts, on_confirm, win_config)
	if is_disabled() then
		return vim.ui.input_orig(opts, on_confirm)
	end

	local prompt = opts.prompt or "Input: "
	local default = opts.default or ""
	local multiline = opts.multiline or false
	on_confirm = on_confirm or function() end

	-- 计算输入框宽度
	local default_width = vim.fn.strdisplaywidth(default) + 10
	local prompt_width = vim.fn.strdisplaywidth(prompt) + 10
	local input_width = math.max(default_width, prompt_width) + 20

	local config = vim.tbl_deep_extend("force", {
		focusable = true,
		style = "minimal",
		border = "rounded",
		title = prompt,
		width = input_width,
		height = 1,
	}, win_config or {}, under_cursor(input_width))

	-- 如果已有窗口则重用
	if existing_window and vim.api.nvim_win_is_valid(existing_window) then
		vim.api.nvim_buf_set_text(existing_buffer, 0, 0, 0, 0, { default })
		vim.api.nvim_win_set_cursor(existing_window, { 1, vim.str_utfindex(default) + 1 }) -- 修复了这里
		vim.cmd("startinsert")
		return
	end

	-- 创建新的窗口和缓冲区
	local buffer = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buffer, true, config)
	vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })

	-- 替换掉废弃的 nvim_win_set_option，改为 nvim_set_option_value
	vim.api.nvim_set_option_value("statuscolumn", "", { scope = "local", win = window })

	existing_window, existing_buffer = window, buffer
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 }) -- 修复了这里
end

--- 浮动输入函数
---@param opts table
---@param on_confirm fun(input: string|nil)
---@param win_config table|nil
function M.input(opts, on_confirm, win_config)
	if is_disabled() then
		return vim.ui.input_orig(opts, on_confirm)
	end

	local prompt = opts.prompt or "Input: "
	local default = opts.default or ""
	local multiline = opts.multiline or false
	on_confirm = on_confirm or function() end

	local default_width = vim.fn.strdisplaywidth(default) + 10
	local prompt_width = vim.fn.strdisplaywidth(prompt) + 10
	local input_width = math.max(default_width, prompt_width) + 20

	local config = vim.tbl_deep_extend("force", {
		focusable = true,
		style = "minimal",
		border = "rounded",
		title = prompt,
		width = input_width,
		height = 1,
	}, win_config or {}, under_cursor(input_width))

	if existing_window and vim.api.nvim_win_is_valid(existing_window) then
		vim.api.nvim_buf_set_text(existing_buffer, 0, 0, 0, 0, { default })
		vim.api.nvim_win_set_cursor(existing_window, { 1, vim.str_utfindex(default) + 1 })
		vim.cmd("startinsert")
		return
	end

	local buffer = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buffer, true, config)
	vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })
	vim.api.nvim_win_set_option(window, "statuscolumn", "")

	existing_window, existing_buffer = window, buffer
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 })

	-- 回车确认
	vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
		local text = lines[1]
		if text and text ~= "" then
			table.insert(input_history, text)
			hist_index = #input_history
		end
		close_window(window, buffer, function()
			vim.schedule(function()
				on_confirm(text)
			end)
		end)
	end, { buffer = buffer })

	if multiline then
		vim.keymap.set("i", "<C-CR>", function()
			local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
			local text = table.concat(lines, "\n")
			if text and text ~= "" then
				table.insert(input_history, text)
				hist_index = #input_history
			end
			on_confirm(text)
			close_window(window, buffer, on_confirm)
		end, { buffer = buffer })
	end

	vim.keymap.set("i", "<Up>", function()
		if hist_index > 1 then
			hist_index = hist_index - 1
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { input_history[hist_index] })
		end
	end, { buffer = buffer })

	vim.keymap.set("i", "<Down>", function()
		if hist_index < #input_history then
			hist_index = hist_index + 1
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { input_history[hist_index] })
		end
	end, { buffer = buffer })

	local augroup = vim.api.nvim_create_augroup("FloatingInputAutoClose", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave", "WinLeave" }, {
		buffer = buffer,
		group = augroup,
		once = true,
		callback = function()
			close_window(window, buffer, on_confirm)
		end,
	})

	local cancel = function()
		close_window(window, buffer, on_confirm)
	end
	vim.keymap.set("n", "<Esc>", cancel, { buffer = buffer })
	vim.keymap.set("n", "q", cancel, { buffer = buffer })
end

-- 自动接管 vim.ui.input
vim.ui.input_orig = vim.ui.input
vim.ui.input = M.input

return M
