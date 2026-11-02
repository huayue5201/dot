-- lua/local/ai/map.lua
---@brief 浮窗地图：按 rex 的真实分屏布局画出格子，点哪个格子就发给哪个 pane 里的 agent。
--
-- 只在 rex 里、且能定位到 block 时才用（见 rex.lua）；否则调用方回落 vim.ui.select。
-- 交互：每个格子里一个字母（按候选顺序 a、b、c…），按字母直接选中；
-- h/j/k/l 按方向选中相邻的格子，也可以直接单击格子；q 或 <Esc> 取消。
-- 画布是只读的静态图：不显示光标（Cursor 映射成背景色），没有底部帮助文字。
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

local MIN_W, MIN_H = 2, 1

-- 候选 → 键位：a、b、c…（超过 26 个就退回数字编号）
local ALPHABET = "abcdefghijklmnopqrstuvwxyz"

local function cells_of(rect, W, H)
	local x = math.floor(rect[1] * W + 0.5) + 1
	local y = math.floor(rect[2] * H + 0.5) + 1
	local w = math.max(1, math.floor(rect[3] * W + 0.5))
	local h = math.max(1, math.floor(rect[4] * H + 0.5))
	-- 留 1 格当分隔缝，但贴着画布边缘的那一侧不留：否则地图最下/最右会空出一条
	-- 没有底色的缝，看起来像浮窗底下多出来一块。
	local x_end = math.floor((rect[1] + rect[3]) * W + 0.5)
	local y_end = math.floor((rect[2] + rect[4]) * H + 0.5)
	local x1 = (x_end >= W) and W or math.min(x + w - 2, W)
	local y1 = (y_end >= H) and H or math.min(y + h - 2, H)
	return x, math.min(y, H), math.max(x1, x), math.max(y1, y)
end

--- 格子里只放一个字母；没有候选的 pane 留空，只靠底色和分缝表达布局
local function pane_label(item)
	if not item then
		return ""
	end
	return item.letter or tostring(item.index)
end

--- 把一段字放在格子正中间（放不下就什么也不放）
local function text_center(g, y0, y1, x0, x1, str, group)
	if not str or str == "" then
		return
	end
	local w = vim.fn.strdisplaywidth(str)
	local y = math.floor((y0 + y1) / 2)
	local x = x0 + math.max(0, math.floor((x1 - x0 + 1 - w) / 2))
	text(g, y, x0, x1, string.rep(" ", math.max(0, x - x0)) .. str, group)
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

--- 画一帧。整块都是格子，没有底栏——内容固定，不会因为候选多少而跳动。
local function paint(panes, by_block, W, H, sel)
	local geom = geometry(panes, by_block, W, H)
	local g = grid_new(W, H)
	local hit = {}
	for _, t in ipairs(geom) do
		if not t.small then
			local group = t.item and (sel == t.item and "AiMapSel" or "AiMapAgent") or "AiMapPane"
			fill(g, t.y0, t.y1, t.x0, t.x1, group)
			text_center(g, t.y0, t.y1, t.x0, t.x1, pane_label(t.item), group)
			for y = t.y0, t.y1 do
				hit[y] = hit[y] or {}
				for x = t.x0, t.x1 do
					hit[y][x] = t.item
				end
			end
		end
	end

	local rows, segs = rows_of(g, W, H)
	return { rows, segs, hit }
end

--- 方向选择：从 from 出发，往 dir（h/j/k/l）方向最近的那个 pane
---@param panes table[]
---@param from table|nil
---@param dir string
---@return table|nil
local function neighbour(panes, from, dir)
	if not from or not from.rect then
		return nil
	end
	local horizontal = dir == "h" or dir == "l"
	local r0 = from.rect
	local fcx, fcy = r0[1] + r0[3] / 2, r0[2] + r0[4] / 2

	local best, best_score
	for _, pane in ipairs(panes) do
		local r = pane.rect
		if r and pane.block_id ~= from.block_id then
			local cx, cy = r[1] + r[3] / 2, r[2] + r[4] / 2
			local along = horizontal and (cx - fcx) or (cy - fcy)
			local forward = ((dir == "l" or dir == "j") and along > 1e-6)
				or ((dir == "h" or dir == "k") and along < -1e-6)
			if forward then
				-- 十字方向优先：侧向中心距的权重比沿方向的距离大，避免跑到斜对角的
				-- 大格子里去（例如从右上角往下，应该去正下方而不是整高的左侧）。
				local cross = horizontal and math.abs(cy - fcy) or math.abs(cx - fcx)
				local score = cross * 4 + math.abs(along)
				if not best_score or score < best_score then
					best, best_score = pane, score
				end
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- 选择器
----------------------------------------------------------------------

--- 打开地图选择器
---@param opts { panes: table[], items: table[], cursor_block?: string, on_choose: fun(item: table|nil) }
function M.select(opts)
	local panes = opts.panes or {}
	local items = opts.items or {}
	define_hl()

	local by_block = {}
	for i, it in ipairs(items) do
		it.letter = ALPHABET:sub(i, i)
		if it.letter == "" then
			it.letter = nil
		end
		if it.block_id then
			by_block[it.block_id] = it
		end
	end

	-- 只看得到本 window 里的 pane；其他候选仍可按字母直达
	local located = {}
	for _, it in ipairs(items) do
		if it.block_id and by_block[it.block_id] == it then
			for _, p in ipairs(panes) do
				if p.block_id == it.block_id then
					table.insert(located, it)
					break
				end
			end
		end
	end

	-- 只需要放一个字母，所以做成小块提示图：屏幕三分之一左右，再多也是空的
	local W = math.min(math.max(math.floor(vim.o.columns * 0.32 + 0.5), 16), 40)
	local H = math.min(math.max(math.floor(vim.o.lines * 0.26 + 0.5), 4), 12)

	-- 消息区（cmdheight 上方那块）的 zindex 比浮窗高，残留的消息会盖在浮窗上，
	-- 表现为中间多出一条竖线或几个乱码字。开窗之前先把消息区清干净。
	pcall(vim.cmd, "silent! messages clear")
	pcall(api.nvim_echo, { { "" } }, false, {})

	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	-- 缩进参考线一类的插件会在光标所在行画竖线（mini.indentscope 的符号就是 │），
	-- 它会盖在地图上，表现为每个 pane 里凭空多出一条竖线。
	vim.b[buf].miniindentscope_disable = true

	local sel = nil
	for _, it in ipairs(located) do
		if it.block_id == opts.cursor_block then
			sel = it
		end
	end
	sel = sel or located[1]

	local hit
	local function repaint()
		local painted = paint(panes, by_block, W, H, sel)
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
		row = math.floor((vim.o.lines - H) / 2),
		col = math.floor((vim.o.columns - W) / 2),
		width = W,
		height = H,
		style = "minimal",
		-- 不要边框：整块就是地图本身，格子直接贴着屏幕（title 依赖边框，所以一并去掉）
		border = "none",
		-- 不让 WinEnter/BufWinEnter 一类的 autocmd 碰这个窗口：有些插件会往里塞
		-- 行号列/缩进参考线/状态列，在浮窗里渲染出来就是一条竖线或数字。
		noautocmd = true,
	})
	-- 浮窗里什么都不要：行号/折叠/符号/状态列都可能被别的插件注入（statuscol.nvim 会给
	-- 每个新窗口设 statuscolumn），在浮窗里渲染出来就是一条竖线或多余的数字。
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].foldenable = false
	vim.wo[win].statuscolumn = ""
	vim.wo[win].colorcolumn = ""
	vim.wo[win].list = false
	vim.wo[win].spell = false
	vim.wo[win].winbar = ""
	-- Cursor 映射成底色 = 光标不可见：这是只读画布，光标块只会显得脏。
	vim.wo[win].winhighlight = "Normal:AiMapBg,Cursor:AiMapBg,CursorIM:AiMapBg"
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

	-- 当前格子（光标看不见，所以只靠高亮表达）：格子里没有候选时不算
	local function at_current()
		local row = api.nvim_win_get_cursor(win)[1]
		local col = api.nvim_win_get_cursor(win)[2] + 1
		local list = hit and hit[row]
		return list and (list[col] or list[1]) or nil
	end

	local function current_pane()
		local row = api.nvim_win_get_cursor(win)[1]
		local col = api.nvim_win_get_cursor(win)[2] + 1
		local list = hit and hit[row]
		local item = list and (list[col] or list[1]) or nil
		if not item then
			return nil
		end
		for _, p in ipairs(panes) do
			if p.block_id == item.block_id then
				return p
			end
		end
		return nil
	end

	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
	end

	-- 鼠标：点哪个格子直接选哪个（不需要先移光标）
	map("<LeftMouse>", function()
		local ok, pos = pcall(vim.fn.getmousepos)
		if not (ok and pos and pos.winid == win) then
			return
		end
		local list = hit and hit[pos.line]
		local item = list and (list[pos.wincol] or list[pos.column] or list[1])
		if item then
			close(item)
		end
	end, "点选格子")
	map("<CR>", function()
		local item = at_current()
		if item then
			close(item)
		end
	end, "选中当前格子")
	map("q", function()
		close(nil)
	end, "取消")
	map("<Esc>", function()
		close(nil)
	end, "取消")

	-- h/j/k/l：把高亮移到相邻的格子（不直接发送，回车才确认）
	for _, dir in ipairs({ "h", "j", "k", "l" }) do
		map(dir, function()
			local pane = neighbour(panes, current_pane(), dir)
			local item = pane and by_block[pane.block_id]
			if item then
				sel = item
				move_to(item)
				repaint()
			end
		end, "往 " .. dir .. " 方向移动")
	end
	for _, it in ipairs(items) do
		if it.letter then
			local letter = it.letter
			for _, lhs in ipairs({ letter, letter:upper() }) do
				map(lhs, function()
					close(it)
				end, "选 " .. letter)
			end
		end
	end
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

	-- 只读画布：不跟光标走，不做 CursorMoved 重画，内容始终稳定
	local group = api.nvim_create_augroup("AiMapSel" .. buf, { clear = true })
	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			pcall(api.nvim_del_augroup_by_id, group)
		end,
	})
end

return M
