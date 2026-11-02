-- lua/local/ai/map.lua
---@brief 浮窗地图：按 rex 的真实分屏布局画出格子，点哪个格子就发给哪个 pane 里的 agent。
--
-- 只在 rex 里、且能定位到 block 时才用（见 rex.lua）；否则调用方回落 vim.ui.select。
-- 交互：光标停留即高亮，<CR> 或鼠标左键选中，q / <Esc> 取消，数字键直达第 N 个候选。
local api = vim.api
local M = {}

-- 地图 buffer 的 extmark 命名空间（背景色/高亮都靠它）
local NS = api.nvim_create_namespace("ai_map")

local function palette()
	local ok, p = pcall(function()
		return require("feat.terminal.highlights").palette()
	end)
	if ok and type(p) == "table" and p.chip_bg then
		return p
	end
	return { fg = nil, green = nil, dim = nil, bar_strip = nil, chip_bg = nil, chip_fg = nil }
end

local function define_hl()
	local p = palette()
	local blend
	local ok, h = pcall(require, "feat.terminal.highlights")
	if ok and type(h.blend) == "function" then
		blend = h.blend
	else
		blend = function(a)
			return a
		end
	end
	api.nvim_set_hl(0, "AiMapBg", { bg = p.bar_strip, fg = p.dim })
	api.nvim_set_hl(0, "AiMapPane", { bg = p.chip_bg, fg = p.dim })
	api.nvim_set_hl(0, "AiMapAgent", { bg = blend(p.chip_bg, p.green, 0.10), fg = p.green })
	api.nvim_set_hl(0, "AiMapSel", { bg = blend(p.chip_bg, p.green, 0.34), fg = p.green, bold = true })
	api.nvim_set_hl(0, "AiMapLabel", { bg = p.chip_bg, fg = p.chip_fg })
	api.nvim_set_hl(0, "AiMapLegend", { bg = p.bar_strip, fg = p.dim, italic = true })
end

----------------------------------------------------------------------
-- 画布：一格一个显示列，宽字符占两格（后一格 ch 为空串表示续格）
----------------------------------------------------------------------

local function grid_new(W, H)
	local g = {}
	for y = 1, H do
		g[y] = {}
		for x = 1, W do
			g[y][x] = { ch = " ", group = "AiMapBg" }
		end
	end
	return g
end

local function fill(g, y0, y1, x0, x1, group)
	for y = y0, y1 do
		for x = x0, x1 do
			g[y][x] = { ch = " ", group = group }
		end
	end
end

local function chars(str)
	local out = {}
	for i = 1, vim.fn.strchars(str) do
		out[i] = vim.fn.strcharpart(str, i - 1, 1)
	end
	return out
end

local function text(g, y, x0, x1, str, group)
	local col = x0
	for _, ch in ipairs(chars(str)) do
		local w = vim.fn.strdisplaywidth(ch)
		if col + w - 1 > x1 then
			break
		end
		g[y][col] = { ch = ch, group = group }
		for k = 1, w - 1 do
			g[y][col + k] = { ch = "", group = group }
		end
		col = col + w
	end
end

--- 把画布压成行 + 每行的「字节区间 → 高亮组」段
local function rows_of(g, W, H)
	local lines, segs = {}, {}
	for y = 1, H do
		local parts, row_segs = {}, {}
		local byte, run_group, run_start = 0, nil, 0
		for x = 1, W do
			local cell = g[y][x] or { ch = " ", group = "AiMapBg" }
			local ch, grp = cell.ch or " ", cell.group or "AiMapBg"
			if grp ~= run_group then
				if run_group then
					table.insert(row_segs, { run_start, byte, run_group })
				end
				run_group, run_start = grp, byte
			end
			table.insert(parts, ch)
			byte = byte + #ch
		end
		if run_group then
			table.insert(row_segs, { run_start, byte, run_group })
		end
		lines[y] = table.concat(parts)
		segs[y] = row_segs
	end
	return lines, segs
end

----------------------------------------------------------------------
-- 布局 → 画布
----------------------------------------------------------------------

local MIN_W, MIN_H = 8, 2

local function cells_of(rect, W, H)
	local x = math.floor(rect[1] * W + 0.5) + 1
	local y = math.floor(rect[2] * H + 0.5) + 1
	local w = math.max(1, math.floor(rect[3] * W + 0.5))
	local h = math.max(1, math.floor(rect[4] * H + 0.5))
	local x1 = math.min(x + w - 2, W) -- 留 1 格当分隔缝
	local y1 = math.min(y + h - 2, H)
	return x, math.min(y, H), math.max(x1, x), math.max(y1, y)
end

local function pane_label(item, label)
	local parts = {}
	if item then
		table.insert(parts, ("#%d"):format(item.index))
		if item.icon and item.icon ~= "" then
			table.insert(parts, item.icon)
		end
		table.insert(parts, item.name or item.label or "")
	else
		table.insert(parts, "·")
		table.insert(parts, label or "")
	end
	return table.concat(parts, " ")
end

--- 把 rex 的叶子几何算成字符格（1-based，左下含端点），并标出「太小放不下标签」的
---@param panes table[]
---@param by_block table<string, table>
---@param W integer
---@param H integer
---@return table[] geom  { { pane, item, x0, y0, x1, y1, small } }
local function geometry(panes, by_block, W, H)
	local out = {}
	for _, pane in ipairs(panes) do
		local item = by_block[pane.block_id]
		local x0, y0, x1, y1 = cells_of(pane.rect, W, H)
		local small = (x1 - x0 + 1 < MIN_W) or (y1 - y0 + 1 < MIN_H)
		table.insert(out, { pane = pane, item = item, x0 = x0, y0 = y0, x1 = x1, y1 = y1, small = small })
	end
	return out
end

--- 画一帧。footer 占底部若干行，不覆盖格子。
local function paint(panes, by_block, labels, W, H, sel, footer)
	local geom = geometry(panes, by_block, W, H)
	-- 格子太小的候选也要在底部点名
	local too_small = {}
	for _, g in ipairs(geom) do
		if g.small and g.item then
			table.insert(too_small, ("#%d"):format(g.item.index))
		end
	end
	local lines = {}
	if #too_small > 0 then
		table.insert(lines, ("格子太小，按数字键直达：%s"):format(table.concat(too_small, " ")))
	end
	for _, line in ipairs(footer or {}) do
		table.insert(lines, line)
	end
	local foot_h = math.min(#lines, math.max(H - MIN_H, 0))
	local pane_h = H - foot_h

	local g = grid_new(W, H)
	local hit = {}
	for _, t in ipairs(geom) do
		-- 底部若干行让给 footer：pane 底部相应收短，而不是整块消失
		local y1 = math.min(t.y1, pane_h)
		if not t.small and y1 - t.y0 + 1 >= 2 then
			local group = t.item and (sel == t.item and "AiMapSel" or "AiMapAgent") or "AiMapPane"
			fill(g, t.y0, y1, t.x0, t.x1, group)
			local ty = (y1 - t.y0 + 1 >= 3) and (t.y0 + 1) or t.y0
			text(g, ty, t.x0 + 1, t.x1, pane_label(t.item, labels[t.pane.block_id]), group)
			for y = t.y0, y1 do
				hit[y] = hit[y] or {}
				for x = t.x0, t.x1 do
					hit[y][x] = t.item
				end
			end
		end
	end

	local y = pane_h + 1
	for i = 1, foot_h do
		local line = lines[i] or ""
		local pad = math.max(0, W - vim.fn.strdisplaywidth(line) - 1)
		text(g, y, 1, W, line .. string.rep(" ", pad), "AiMapLegend")
		y = y + 1
	end

	local rows, segs = rows_of(g, W, H)
	return { rows, segs, hit }
end

----------------------------------------------------------------------
-- 选择器
----------------------------------------------------------------------

--- 打开地图选择器
---@param opts { panes: table[], labels: table<string,string>, items: table[], cursor_block?: string, title?: string, on_choose: fun(item: table|nil) }
function M.select(opts)
	local panes = opts.panes or {}
	local items = opts.items or {}
	define_hl()

	local by_block = {}
	for _, it in ipairs(items) do
		if it.block_id then
			by_block[it.block_id] = it
		end
	end

	-- 本 window 里定位不到的候选，用底部文字列出来
	local located, footer = {}, {}
	for _, it in ipairs(items) do
		if it.block_id and by_block[it.block_id] == it then
			local found = false
			for _, p in ipairs(panes) do
				if p.block_id == it.block_id then
					found = true
					break
				end
			end
			if found then
				table.insert(located, it)
			end
		end
	end
	local in_panes = {}
	for _, it in ipairs(located) do
		in_panes[it.index] = true
	end
	local stray = {}
	for _, it in ipairs(items) do
		if not in_panes[it.index] then
			table.insert(stray, it)
		end
	end
	if #stray > 0 then
		local names = {}
		for _, it in ipairs(stray) do
			table.insert(names, ("#%d"):format(it.index))
		end
		table.insert(footer, ("不在这个 window，按数字键直达：%s"):format(table.concat(names, " ")))
	end

	local W = math.min(math.max(vim.o.columns - 6, 30), 110)
	local H = math.min(math.max(vim.o.lines - 8, 8), 34)

	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false

	local sel = nil
	for _, it in ipairs(located) do
		if it.block_id == opts.cursor_block then
			sel = it
		end
	end
	sel = sel or located[1]

	local hit
	local function repaint()
		local painted = paint(panes, by_block, opts.labels or {}, W, H, sel, footer)
		local lines, segs, h = painted[1], painted[2], painted[3]
		hit = h
		vim.bo[buf].modifiable = true
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		api.nvim_buf_clear_namespace(buf, NS, 0, -1)
		for y, list in ipairs(segs) do
			for _, seg in ipairs(list) do
				if seg[2] > seg[1] then
					pcall(api.nvim_buf_set_extmark, buf, NS, y - 1, seg[1], {
						end_col = seg[2],
						hl_group = seg[3],
						priority = 10,
					})
				end
			end
		end
	end

	repaint()

	local win = api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - H) / 2) - 1,
		col = math.floor((vim.o.columns - W) / 2),
		width = W,
		height = H,
		style = "minimal",
		border = "rounded",
		title = " " .. (opts.title or "发到哪个 agent？") .. " ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	vim.wo[win].winhighlight = "Normal:AiMapBg"
	api.nvim_set_current_win(win)

	local finished = false
	local function close(item)
		if finished then
			return
		end
		finished = true
		if api.nvim_win_is_valid(win) then
			api.nvim_win_close(win, true)
		end
		if api.nvim_buf_is_valid(buf) then
			pcall(api.nvim_buf_delete, buf, { force = true })
		end
		if opts.on_choose then
			opts.on_choose(item)
		end
	end

	local function move_to(item)
		for y, list in pairs(hit or {}) do
			for x, it in pairs(list) do
				if it == item then
					pcall(api.nvim_win_set_cursor, win, { y, x - 1 })
					return true
				end
			end
		end
		return false
	end

	if sel then
		move_to(sel)
	end

	local function at_cursor()
		local row = api.nvim_win_get_cursor(win)[1]
		local col = vim.fn.virtcol(".")
		local list = hit and hit[row]
		if not list then
			return nil
		end
		if list[col] then
			return list[col]
		end
		for x = 1, W do
			if list[x] then
				return list[x]
			end
		end
		return nil
	end

	local map = function(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
	end

	map("<CR>", function()
		local item = at_cursor()
		if item then
			close(item)
		end
	end, "选中光标所在格子")
	map("<LeftMouse>", function()
		-- 鼠标先落在某格：点一下等于「移过去 + 选中」
		local ok, pos = pcall(vim.fn.getmousepos)
		if ok and pos and pos.winid == win then
			pcall(api.nvim_win_set_cursor, win, { pos.line, math.max(pos.column - 1, 0) })
			local item = at_cursor()
			if item then
				close(item)
			end
		end
	end, "点选格子")
	map("<2-LeftMouse>", function()
		local item = at_cursor()
		if item then
			close(item)
		end
	end, "双击选中")
	map("q", function()
		close(nil)
	end, "取消")
	map("<Esc>", function()
		close(nil)
	end, "取消")
	for i = 1, 9 do
		map(tostring(i), function()
			for _, it in ipairs(items) do
				if it.index == i then
					close(it)
					return
				end
			end
		end, "直达第 " .. i .. " 个候选")
	end

	local group = api.nvim_create_augroup("AiMapSel" .. buf, { clear = true })
	api.nvim_create_autocmd("CursorMoved", {
		group = group,
		buffer = buf,
		callback = function()
			local item = at_cursor()
			if item and item ~= sel then
				sel = item
				repaint()
				move_to(item)
			end
		end,
	})
	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			pcall(api.nvim_del_augroup_by_id, group)
		end,
	})
end

return M
