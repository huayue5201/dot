-- lua/core/save-panel.lua
-- 未保存 buffer 列表浮窗：逐条保存 / 全部保存 / 跳转。
--
-- 交互参考 lsp-config/panel.lua：
--   圆角浮窗、j/k 移动、数字跳转、<CR> 执行、? 帮助、q/Esc/<Tab> 关闭。
local M = {}

local unsaved = require("core.unsaved")

local panel = { win = nil, buf = nil }
local rows = {} -- 当前面板行（与缓冲区行号一一对应）
local parent_win = nil -- 打开面板前的窗口，跳转时用

local function win_valid()
	return panel.win and vim.api.nvim_win_is_valid(panel.win)
end

local function close()
	if win_valid() then
		pcall(vim.api.nvim_win_close, panel.win, true)
	end
	panel.win, panel.buf = nil, nil
	pcall(vim.api.nvim_del_augroup_by_name, "save_panel_refresh")
end

---------------------------------------------------------------------
-- 行构造 / 渲染
---------------------------------------------------------------------
local function short_name(path)
	return vim.fn.fnamemodify(path, ":t")
end

local function short_dir(path)
	return vim.fn.fnamemodify(path, ":~:h")
end

local function render(buf, list)
	local name_width = 0
	for _, r in ipairs(list) do
		name_width = math.max(name_width, vim.fn.strdisplaywidth(short_name(r.name)))
	end

	local lines = {}
	for i, r in ipairs(list) do
		local nm = short_name(r.name)
		local pad = string.rep(" ", name_width - vim.fn.strdisplaywidth(nm))
		local ft = r.ft ~= "" and ("[" .. r.ft .. "]") or ""
		lines[i] = string.format("● %s%s  %s  %s", nm, pad, short_dir(r.name), ft)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
	for i, r in ipairs(list) do
		vim.api.nvim_buf_add_highlight(buf, -1, "SaveDotDirty", i - 1, 0, 1)
		vim.api.nvim_buf_add_highlight(buf, -1, "Title", i - 1, 2, 2 + vim.fn.strdisplaywidth(short_name(r.name)))
	end
end

---------------------------------------------------------------------
-- 帮助浮窗
---------------------------------------------------------------------
local HELP = {
	{ "<CR>", "保存选中 buffer" },
	{ "a / <C-s>", "保存全部" },
	{ "o / <Tab>", "跳转到该 buffer" },
	{ "j / k", "上下移动" },
	{ "1-9", "直接保存对应行" },
	{ "r", "刷新列表" },
	{ "?", "显示/隐藏本帮助" },
	{ "q / <Esc>", "关闭面板" },
}

---@param parent integer|nil
local function show_help(parent)
	local hbuf = vim.api.nvim_create_buf(false, true)

	local lines = {}
	local width = 40
	for _, kv in ipairs(HELP) do
		local line = string.format("  %-14s %s", kv[1], kv[2])
		lines[#lines + 1] = line
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(width + 4, 84)

	local height = #lines + 2
	local margin = 2
	local col = math.max(0, vim.o.columns - width - margin)
	local row = math.max(0, vim.o.lines - vim.o.cmdheight - height - margin)
	local hwin = vim.api.nvim_open_win(hbuf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = "rounded",
		style = "minimal",
		title = " 未保存 buffer · 按键帮助 ",
		title_pos = "center",
		zindex = 200,
	})

	vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
	vim.bo[hbuf].modifiable = false
	vim.bo[hbuf].bufhidden = "wipe"
	for i, kv in ipairs(HELP) do
		vim.api.nvim_buf_add_highlight(hbuf, -1, "Special", i - 1, 2, 2 + #kv[1])
	end

	local function close_help()
		pcall(vim.api.nvim_win_close, hwin, true)
		if parent and vim.api.nvim_win_is_valid(parent) then
			vim.api.nvim_set_current_win(parent)
		end
	end
	for _, key in ipairs({ "q", "<Esc>", "?", "<CR>" }) do
		vim.keymap.set("n", key, close_help, { buffer = hbuf, nowait = true })
	end
end

---------------------------------------------------------------------
-- 操作
---------------------------------------------------------------------
local function write_buf(bufnr)
	local ok, err = pcall(function()
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("silent write")
		end)
	end)
	if not ok then
		vim.notify("保存失败: " .. vim.fn.fnamemodify(vim.fn.bufname(bufnr), ":t") .. "\n" .. tostring(err), vim.log.levels.ERROR)
	end
end

local function open_buf(bufnr)
	local target = parent_win
	close()
	if target and vim.api.nvim_win_is_valid(target) then
		vim.api.nvim_set_current_win(target)
	end
	vim.cmd("buffer " .. bufnr)
end

local function refresh()
	if not win_valid() then
		return
	end

	local list = {}
	for _, r in ipairs(unsaved.list()) do
		if r.writable then
			list[#list + 1] = r
		end
	end

	if #list == 0 then
		close()
		vim.notify("所有 buffer 已保存", vim.log.levels.INFO)
		return
	end

	rows = list
	render(panel.buf, rows)

	-- 行数变少时把光标夹回有效行
	local c = vim.api.nvim_win_get_cursor(panel.win)[1]
	if c > #rows then
		vim.api.nvim_win_set_cursor(panel.win, { #rows, 0 })
	end
end

---------------------------------------------------------------------
-- 打开 / 关闭
---------------------------------------------------------------------
function M.toggle()
	if win_valid() then
		close()
		return
	end

	local list = {}
	for _, r in ipairs(unsaved.list()) do
		if r.writable then
			list[#list + 1] = r
		end
	end
	if #list == 0 then
		vim.notify("没有未保存的 buffer", vim.log.levels.INFO)
		return
	end
	rows = list

	-- 面板宽度：按最长行估算
	local width = 44
	for _, r in ipairs(rows) do
		local w = vim.fn.strdisplaywidth(short_name(r.name)) + vim.fn.strdisplaywidth(short_dir(r.name)) + 12
		width = math.max(width, w)
	end
	width = math.min(width, math.max(20, vim.o.columns - 4))
	local height = math.min(#rows + 1, math.max(3, vim.o.lines - 6))

	parent_win = vim.api.nvim_get_current_win()

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		style = "minimal",
		title = " 未保存 buffer ",
		title_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"
	panel.win, panel.buf = win, buf

	render(buf, rows)

	local aug = vim.api.nvim_create_augroup("save_panel_refresh", { clear = true })
	vim.api.nvim_create_autocmd({ "BufWritePost", "TextChanged", "TextChangedI", "BufDelete", "BufAdd", "BufUnload" }, {
		group = aug,
		callback = function()
			vim.schedule(refresh)
		end,
	})

	local function cursor_line()
		return vim.api.nvim_win_get_cursor(win)[1]
	end

	local opts = { buffer = buf, nowait = true }

	-- <CR>：保存选中行
	vim.keymap.set("n", "<CR>", function()
		local r = rows[cursor_line()]
		if r then
			write_buf(r.buf)
			refresh()
		end
	end, opts)

	-- a / <C-s>：全部保存
	local function save_all()
		for _, r in ipairs(rows) do
			write_buf(r.buf)
		end
		refresh()
	end
	vim.keymap.set("n", "a", save_all, opts)
	vim.keymap.set("n", "<C-s>", save_all, opts)

	-- o / <Tab>：跳转到该 buffer
	local function jump()
		local r = rows[cursor_line()]
		if r then
			open_buf(r.buf)
		end
	end
	vim.keymap.set("n", "o", jump, opts)
	vim.keymap.set("n", "<Tab>", jump, opts)

	-- r：刷新
	vim.keymap.set("n", "r", refresh, opts)

	-- j/k：移动
	vim.keymap.set("n", "j", function()
		local c = cursor_line()
		if c < #rows then
			vim.api.nvim_win_set_cursor(win, { c + 1, 0 })
		end
	end, opts)
	vim.keymap.set("n", "k", function()
		local c = cursor_line()
		if c > 1 then
			vim.api.nvim_win_set_cursor(win, { c - 1, 0 })
		end
	end, opts)

	-- 数字键：直接保存对应行
	for i = 1, math.min(#rows, 9) do
		vim.keymap.set("n", tostring(i), function()
			local r = rows[i]
			if r then
				write_buf(r.buf)
				refresh()
			end
		end, opts)
	end

	-- ?：帮助
	vim.keymap.set("n", "?", function()
		show_help(win)
	end, opts)

	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)
end

---注册用户命令
function M.setup()
	vim.api.nvim_create_user_command("SavePanel", function()
		M.toggle()
	end, { desc = "未保存 buffer 列表" })
end

return M
