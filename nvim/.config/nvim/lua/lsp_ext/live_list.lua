--- 让 loclist / quickfix 里的诊断列表随 vim.diagnostic 变化就地刷新。
---
--- 每种列表各维护一份（grd 的 loclist 与 grD 的 quickfix 可以同时实时）：
--- 同一种列表再次 attach 会替换上一次的监听；源窗口或列表窗口关掉、
--- 列表被别的来源（gitsigns / references / 用户 :colder）覆盖时自动注销，
--- 不会去覆盖别人的列表，也不会抢焦点。
---
--- 刷新时按 (bufnr, lnum) 找回光标所在条目，避免条目增删导致光标漂移。

local M = {}

---@type table<string, table>
local active = {}

local function stop_one(s)
	if s.timer then
		s.timer:stop()
		if not s.timer:is_closing() then
			s.timer:close()
		end
		s.timer = nil
	end
	if s.group then
		pcall(vim.api.nvim_del_augroup_by_id, s.group)
		s.group = nil
	end
	if active[s.kind] == s then
		active[s.kind] = nil
	end
end

--- 停掉所有实时列表监听
function M.stop()
	for _, s in pairs(active) do
		stop_one(s)
	end
	active = {}
end

local function list_items(s, list_win)
	if s.kind == "loclist" then
		return vim.fn.getloclist(list_win, { items = 1 }).items or {}
	end
	return vim.fn.getqflist({ items = 1 }).items or {}
end

local function set_list(s, items)
	if s.kind == "loclist" then
		vim.fn.setloclist(s.srcwin, {}, "r", { items = items, title = s.title })
	else
		vim.fn.setqflist({}, "r", { items = items, title = s.title })
	end
end

local function refresh(s)
	if not s.group then
		return
	end
	if s.kind == "loclist" then
		if not (s.srcwin and vim.api.nvim_win_is_valid(s.srcwin)) then
			return stop_one(s)
		end
		if not (s.srcbuf and vim.api.nvim_buf_is_valid(s.srcbuf)) then
			return stop_one(s)
		end
	end

	local list_win = s.find_win()
	if not list_win then
		return stop_one(s)
	end
	if not s.is_ours() then
		return stop_one(s)
	end

	-- 记住光标下的条目，刷新后按 (bufnr, lnum) 找回
	local old_items = list_items(s, list_win)
	local line = vim.api.nvim_win_get_cursor(list_win)[1]
	local anchor = old_items[line]

	local items = s.build(s)
	set_list(s, items)

	if not vim.api.nvim_win_is_valid(list_win) then
		return
	end
	local target
	if anchor then
		for i, item in ipairs(items) do
			if item.bufnr == anchor.bufnr and item.lnum == anchor.lnum then
				target = i
				break
			end
		end
	end
	target = target or math.min(line, #items)
	if target >= 1 then
		pcall(vim.api.nvim_win_set_cursor, list_win, { target, 0 })
	end
end

local function schedule_refresh(s)
	if not s.group then
		return
	end
	if not s.timer then
		s.timer = (vim.uv or vim.loop).new_timer()
	end
	s.timer:stop()
	s.timer:start(
		s.debounce,
		0,
		vim.schedule_wrap(function()
			refresh(s)
		end)
	)
end

--- @param opts { kind: "loclist"|"quickfix", title: string, build: fun(s): table, find_win: fun(): integer?, is_ours: fun(): boolean, srcwin?: integer, srcbuf?: integer, debounce?: integer }
--- @return table|nil handle { stop = fun() }
function M.attach(opts)
	local old = active[opts.kind]
	if old then
		stop_one(old)
	end
	if not opts.find_win() then
		return -- 列表窗口没开，不用挂监听
	end

	local s = {
		kind = opts.kind,
		title = opts.title,
		srcwin = opts.srcwin,
		srcbuf = opts.srcbuf,
		build = opts.build,
		find_win = opts.find_win,
		is_ours = opts.is_ours,
		debounce = opts.debounce or 150,
	}
	s.group = vim.api.nvim_create_augroup("UserLiveDiagnosticsList_" .. s.kind, { clear = true })
	active[s.kind] = s

	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = s.group,
		callback = function(ev)
			-- loclist 只管自己的 buffer；quickfix 是全局列表，任何 buffer 的变化都相关
			if s.kind == "loclist" and ev.buf ~= s.srcbuf then
				return
			end
			schedule_refresh(s)
		end,
	})

	if s.kind == "loclist" then
		-- 文件窗口里换 buffer 时，loclist 跟着换成新 buffer 的诊断
		vim.api.nvim_create_autocmd("BufEnter", {
			group = s.group,
			callback = function(ev)
				if vim.api.nvim_get_current_win() ~= s.srcwin then
					return
				end
				s.srcbuf = ev.buf
				schedule_refresh(s)
			end,
		})
	end

	vim.api.nvim_create_autocmd("WinClosed", {
		group = s.group,
		callback = function()
			vim.schedule(function()
				if not s.group then
					return
				end
				if s.kind == "loclist" and not (s.srcwin and vim.api.nvim_win_is_valid(s.srcwin)) then
					return stop_one(s)
				end
				if not s.find_win() then
					stop_one(s)
				end
			end)
		end,
	})

	return { stop = function()
		stop_one(s)
	end }
end

return M
