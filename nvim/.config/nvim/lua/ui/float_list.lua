-- lua/ui/float_list.lua
--[[
浮窗列表（内部共享库，不对外发布）
==================================
lsp_ext/panel.lua、core/save-panel.lua 原本各抄了一份「圆角居中浮窗 + j/k
+ 数字跳转 + <CR> 执行 + ? 帮助 + q/Esc 关闭」，行为已经漂移。这里把这份交互
收成一个可复用实例：（dap_ext/exception-breakpoints.lua 已改用 nvim-dap-view，不再需要）

    local list = require("ui.float_list").new({
      title = " 某某面板 ",
      rows = function() ... end,      -- 数据源：条目数组
      text = function(item) ... end,  -- 每行文本
      highlights = function(item) ... end, -- 可选：{{group, start, finish}}
      enter = function(item, idx) ... end, -- <CR>
      keymaps = { { "R", function() ... end, "重启" } },
      help = { { "<CR>", "切换" } },
      refresh_events = { "LspAttach", "LspDetach" },
    })
    list:toggle()

约定：
  * 面板只负责「行内容 + 对单行的动作」，按键/浮窗/光标/刷新/帮助都由本库处理
  * 动作返回 true 时自动重绘（不需要精确控制的直接改完不返回也行，refresh 会重画）
  * on_close(reason) 的 reason 来自 close_keys（默认 "cancel"），用于区分取消/确认
]]
local M = {}

local ns = vim.api.nvim_create_namespace("ui.float_list")

local DEFAULT_CLOSE = { q = "cancel", ["<Esc>"] = "cancel" }

----------------------------------------------------------------------
-- 通用帮助浮窗（三处共用）
----------------------------------------------------------------------

---@param opts {title?: string, items: table[], zindex?: integer, on_close?: fun()}
---@return integer win
---@return integer buf
function M.help(opts)
	local items = opts.items or {}
	local key_w = 2
	for _, it in ipairs(items) do
		key_w = math.max(key_w, vim.fn.strdisplaywidth(it[1]))
	end

	local lines = {}
	for i, it in ipairs(items) do
		lines[i] = ("  %-" .. key_w .. "s  %s"):format(it[1], it[2] or "")
	end

	local width = 20
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
	end
	width = math.min(width, math.max(20, vim.o.columns - 4))
	local height = math.max(1, math.min(#lines, vim.o.lines - 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	for row, line in ipairs(lines) do
		local key = items[row][1]
		pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, 2, {
			end_col = math.min(2 + #key, #line),
			hl_group = "Special",
		})
	end

	local cfg = {
		relative = "editor",
		anchor = "SE",
		row = vim.o.lines - 2,
		col = vim.o.columns - 2,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		zindex = opts.zindex or 200,
	}
	if opts.title then
		cfg.title, cfg.title_pos = opts.title, "center"
	end
	local win = vim.api.nvim_open_win(buf, true, cfg)
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if opts.on_close then
			opts.on_close()
		end
	end
	for _, lhs in ipairs({ "q", "<Esc>", "?", "<CR>" }) do
		vim.keymap.set("n", lhs, close, { buffer = buf, nowait = true })
	end
	return win, buf
end

----------------------------------------------------------------------
-- List
----------------------------------------------------------------------

local List = {}
List.__index = List

---@param opts table
function M.new(opts)
	local self = setmetatable({
		opts = opts,
		win = nil,
		buf = nil,
		items = {},
		lines = {},
		parent_win = nil,
	}, List)
	return self
end

function List:is_open()
	return self.win ~= nil and vim.api.nvim_win_is_valid(self.win)
end

--- 当前光标所在的条目下标（1-based），无条目返回 nil
function List:current()
	if not self:is_open() then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(self.win)[1]
	return self.items[row] and row or nil
end

--- 收集行内容 + 高亮（不写 buffer）
function List:_build()
	local opts = self.opts
	local items = opts.rows and opts.rows() or {}
	self.items = items
	local lines = {}
	for i, item in ipairs(items) do
		local text = opts.text and opts.text(item) or (type(item) == "table" and item.text) or tostring(item)
		lines[i] = text
	end
	return items, lines
end

function List:_geometry(n)
	local opts = self.opts
	local columns, rows = vim.o.columns, vim.o.lines
	local width = opts.width
	if type(width) == "function" then
		width = width(n)
	elseif not width then
		width = 20
		for _, l in ipairs(self.lines) do
			width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
		end
	end
	width = math.max(10, math.min(width, columns - 4))

	local height = opts.height
	if type(height) == "function" then
		height = height(n)
	elseif not height then
		height = n
	end
	local max_height = math.min(opts.max_height or math.floor(rows * 0.6), rows - 4)
	height = math.max(1, math.min(math.max(height, 1), max_height))
	return width, height
end

function List:_draw()
	if not self:is_open() then
		return
	end
	local _, lines = self:_build()
	if #lines == 0 then
		lines = { "  (无内容)" }
	end
	self.lines = lines

	vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(self.buf, ns, 0, -1)

	local hl_fn = self.opts.highlights
	if hl_fn then
		for i, item in ipairs(self.items) do
			local line = lines[i] or ""
			for _, h in ipairs(hl_fn(item) or {}) do
				local s = math.min(h[2] or 0, #line)
				local e = math.min(h[3] or #line, #line)
				if e > s then
					pcall(vim.api.nvim_buf_set_extmark, self.buf, ns, i - 1, s, {
						end_col = e,
						hl_group = h[1],
					})
				end
			end
		end
	end

	local width, height = self:_geometry(#lines)
	local cfg = vim.api.nvim_win_get_config(self.win)
	cfg.width, cfg.height = width, height
	cfg.row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
	cfg.col = math.max(0, math.floor((vim.o.columns - width) / 2))
	vim.api.nvim_win_set_config(self.win, cfg)

	-- 光标夹紧，保持在同一行
	local row = math.min(vim.api.nvim_win_get_cursor(self.win)[1], #self.items)
	vim.api.nvim_win_set_cursor(self.win, { math.max(1, row), 0 })
end

function List:_move(step)
	if not self:is_open() or #self.items == 0 then
		return
	end
	local row = vim.api.nvim_win_get_cursor(self.win)[1]
	local target = math.max(1, math.min(#self.items, row + step))
	vim.api.nvim_win_set_cursor(self.win, { target, 0 })
end

--- 对当前行执行动作（带 nil 保护）
function List:_act(key)
	local idx = self:current()
	if not idx then
		return
	end
	local fn = self.opts[key]
	if fn then
		fn(self.items[idx], idx, self)
	end
end

function List:_bind()
	local opts = self.opts
	local function map(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = self.buf, nowait = true })
	end

	map("j", function()
		self:_move(1)
	end)
	map("k", function()
		self:_move(-1)
	end)
	map("g", function()
		if self:is_open() and #self.items > 0 then
			vim.api.nvim_win_set_cursor(self.win, { 1, 0 })
		end
	end)
	map("G", function()
		if self:is_open() and #self.items > 0 then
			vim.api.nvim_win_set_cursor(self.win, { #self.items, 0 })
		end
	end)
	map("<CR>", function()
		self:_act("enter")
	end)
	if opts.on_number ~= false and opts.number_keys ~= false then
		for i = 1, 9 do
			map(tostring(i), function()
				local item = self.items[i]
				if item and opts.on_number then
					opts.on_number(item, i, self)
				end
			end)
		end
	end
	if opts.help then
		map("?", function()
			M.help({ title = opts.help_title, items = opts.help })
		end)
	end
	for _, km in ipairs(opts.keymaps or {}) do
		local lhs, action = km[1], km[2]
		if type(action) == "string" then
			local name = action
			action = function()
				if type(self[name]) == "function" then
					self[name](self)
				end
			end
		elseif type(action) == "function" then
			local fn = action
			action = function()
				fn(self)
			end
		end
		map(lhs, action)
	end
	local close_keys = opts.close_keys or DEFAULT_CLOSE
	for lhs, reason in pairs(close_keys) do
		map(lhs, function()
			self:close(reason)
		end)
	end
end

---@param reason? string
function List:close(reason)
	if not self:is_open() then
		return
	end
	local win, buf, parent = self.win, self.buf, self.parent_win
	self.win, self.buf = nil, nil
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	if buf and vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	if parent and vim.api.nvim_win_is_valid(parent) and vim.api.nvim_get_current_win() ~= parent then
		vim.api.nvim_set_current_win(parent)
	end
	if self.opts.refresh_events and #self.opts.refresh_events > 0 then
		pcall(vim.api.nvim_del_augroup_by_name, self.opts.refresh_augroup or "core_float_list_refresh")
	end
	if self.opts.on_close then
		self.opts.on_close(reason or "cancel")
	end
end

function List:open()
	local opts = self.opts
	local items, lines = self:_build()
	-- 静默约定：数据为空时直接不打开，不弹任何提示
	if opts.guard and opts.guard(items) then
		return
	end
	if #lines == 0 then
		return
	end

	self.parent_win = vim.api.nvim_get_current_win()
	self.lines = lines
	self.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[self.buf].bufhidden = "wipe"

	local width, height = self:_geometry(math.max(#lines, 1))
	local cfg = {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
	}
	if opts.title then
		cfg.title, cfg.title_pos = opts.title, "center"
	end
	self.win = vim.api.nvim_open_win(self.buf, true, cfg)
	vim.wo[self.win].cursorline = false
	vim.wo[self.win].wrap = false

	self:_bind()
	self:_draw()

	if opts.refresh_events and #opts.refresh_events > 0 then
		-- 关闭时随 buffer 一起清理，避免重复注册
		local augroup = vim.api.nvim_create_augroup(opts.refresh_augroup or "core_float_list_refresh", { clear = true })
		vim.api.nvim_create_autocmd(opts.refresh_events, {
			group = augroup,
			callback = function(ev)
				if opts.refresh_filter and not opts.refresh_filter(ev) then
					return
				end
				vim.schedule(function()
					if self:is_open() then
						self:refresh()
					end
				end)
			end,
		})
	end
end

function List:toggle()
	if self:is_open() then
		self:close("toggle")
	else
		self:open()
	end
end

--- 重新取数据并重绘；条目清空时按 close_when_empty 自动关闭
function List:refresh()
	if not self:is_open() then
		return false
	end
	local opts = self.opts
	local items = opts.rows and opts.rows() or {}
	if #items == 0 and opts.close_when_empty ~= false then
		self:close("empty")
		return false
	end
	self:_draw()
	return true
end

return M
