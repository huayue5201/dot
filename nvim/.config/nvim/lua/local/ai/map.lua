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
	-- 浮层（rex 里被 float 出来的 pane）比平铺层亮一点，好在覆盖的地方看得出层次
	api.nvim_set_hl(0, "AiMapFloat", { bg = blend(p.chip_bg, p.fg, 0.12), fg = p.dim })
	api.nvim_set_hl(0, "AiMapFloatSel", { bg = blend(blend(p.chip_bg, p.fg, 0.12), p.green, 0.34), fg = p.green, bold = true })
	-- 底部那行「窗口外：…」的说明，用轨道底色 + 暗字，不抢格子的注意力
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



-- 候选 → 键位：a、b、c…（超过 26 个就退回数字编号）
local ALPHABET = "abcdefghijklmnopqrstuvwxyz"
-- h/j/k/l 被方向键占用了：候选多于 7 个时，第 8 个候选的字母正好是 h，会和「往左
-- 移动」撞车，所以分字母时跳过这四个。超过 22 个候选再用数字。
local RESERVED = { h = true, j = true, k = true, l = true }
local LETTERS = {}
for i = 1, #ALPHABET do
	local ch = ALPHABET:sub(i, i)
	if not RESERVED[ch] then
		LETTERS[#LETTERS + 1] = ch
	end
end

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

--- 把 rex 的叶子几何算成字符格（1-based，左下含端点），并标出「太小放不下标签」的
---@param panes table[]
---@param by_block table<string, table>
---@param W integer
---@param H integer
---@return table[] geom  { { pane, item, x0, y0, x1, y1 } }
local function geometry(panes, by_block, W, H)
	local out = {}
	for _, pane in ipairs(panes) do
		local item = by_block[pane.block_id]
		local x0, y0, x1, y1 = cells_of(pane.rect, W, H)
		table.insert(out, { pane = pane, item = item, x0 = x0, y0 = y0, x1 = x1, y1 = y1 })
	end
	return out
end

--- 画一帧。整块都是格子，没有底栏——内容固定，不会因为候选多少而跳动。
local function paint(panes, by_block, W, H, sel, note)
	-- 底部要留一行写字时，画布按 H-1 算，别让说明覆盖掉最下面那块 pane
	local canvas_h = note and (H - 1) or H
	local geom = geometry(panes, by_block, W, canvas_h)
	local g = grid_new(W, H)
	local hit, owner = {}, {}
	for _, t in ipairs(geom) do
		local float = t.pane.kind == "floating"
		local group
		if t.item then
			if sel == t.item then
				group = float and "AiMapFloatSel" or "AiMapSel"
			else
				group = "AiMapAgent"
			end
		else
			group = float and "AiMapFloat" or "AiMapPane"
		end
		fill(g, t.y0, t.y1, t.x0, t.x1, group)
		for y = t.y0, t.y1 do
			hit[y] = hit[y] or {}
			owner[y] = owner[y] or {}
			for x = t.x0, t.x1 do
				hit[y][x] = t.item
				owner[y][x] = t.pane
			end
		end
	end

	-- 字母第二遍再放：浮层会盖住底下那块 pane 的中心，如果第一遍就把字母写进去，
	-- 被盖住的字母就消失了（用户看得见的那块却没有字母）。所以只往「还有自己底色」
	-- 的格子里放，取这些格子的中间一个。
	for _, t in ipairs(geom) do
		local letter = pane_label(t.item)
		if letter and letter ~= "" then
			local cells = {}
			for y = t.y0, t.y1 do
				for x = t.x0, t.x1 do
					if owner[y] and owner[y][x] == t.pane then
						cells[#cells + 1] = { y, x }
					end
				end
			end
			if #cells > 0 then
				local mid = cells[math.floor((#cells + 1) / 2)]
				local float = t.pane.kind == "floating"
				local group
				if t.item then
					group = (sel == t.item) and (float and "AiMapFloatSel" or "AiMapSel") or "AiMapAgent"
				else
					group = float and "AiMapFloat" or "AiMapPane"
				end
				text(g, mid[1], mid[2], mid[2], letter, group)
			end
		end
	end

	if note and note ~= "" then
		text(g, H, 1, W, note, "AiMapLegend")
	end

	local rows, segs = rows_of(g, W, H)
	return { rows, segs, hit }
end

--- 方向选择：从 from 出发，往 dir（h/j/k/l）方向最近的那个 pane
---@param panes table[]
---@param from table|nil
---@param dir string
---@return table|nil
local function covers(outer, inner)
	return outer[1] <= inner[1] + 1e-9
		and outer[2] <= inner[2] + 1e-9
		and outer[1] + outer[3] >= inner[1] + inner[3] - 1e-9
		and outer[2] + outer[4] >= inner[2] + inner[4] - 1e-9
end

local function neighbour(panes, from, dir)
	if not from or not from.rect then
		return nil
	end
	local horizontal = dir == "h" or dir == "l"
	local r0 = from.rect
	local fcx, fcy = r0[1] + r0[3] / 2, r0[2] + r0[4] / 2

	-- 浮层压在某个 pane 上面：它的四条边都在那块 pane 内部，按方向找邻居永远是空的
	-- （挪不回去就是这么来的）。所以先看「谁包住了我」，四个方向都往它走。
	local holder, holder_area
	for _, pane in ipairs(panes) do
		local r = pane.rect
		if r and pane.block_id ~= from.block_id and covers(r, r0) then
			local area = r[3] * r[4]
			if not holder_area or area < holder_area then
				holder, holder_area = pane, area
			end
		end
	end
	if holder then
		return holder
	end

	-- 按「边到边的空隙」挑邻居，而不是中心点距离：中心点会让远处的浮层看起来比紧贴
	-- 着的分屏更近（浮层小、中心更偏），空隙为 0 的才是真正贴着的那块。
	local best, best_score
	for _, pane in ipairs(panes) do
		local r = pane.rect
		if r and pane.block_id ~= from.block_id then
			local cx, cy = r[1] + r[3] / 2, r[2] + r[4] / 2
			local gap
			if dir == "h" then
				gap = r0[1] - (r[1] + r[3])
			elseif dir == "l" then
				gap = r[1] - (r0[1] + r0[3])
			elseif dir == "j" then
				gap = r[2] - (r0[2] + r0[4])
			else
				gap = r0[2] - (r[2] + r[4])
			end
			if gap >= -1e-6 then
				local cross = horizontal and math.abs(cy - fcy) or math.abs(cx - fcx)
				local score = gap * 4 + cross
				if not best_score or score < best_score then
					best, best_score = pane, score
				end
			end
		end
	end
	if best then
		return best
	end

	-- 整高的 pane（左边那一整列）往上下走时没有任何一块「贴着」，这时才退回按中心点
	-- 找：跨过边界进到另一列的上/下半边。被自己包住的浮层不参与（那不是邻居）。
	for _, pane in ipairs(panes) do
		local r = pane.rect
		if r and pane.block_id ~= from.block_id and not covers(r0, r) then
			local cx, cy = r[1] + r[3] / 2, r[2] + r[4] / 2
			local along = horizontal and (cx - fcx) or (cy - fcy)
			local forward = ((dir == "l" or dir == "j") and along > 1e-6)
				or ((dir == "h" or dir == "k") and along < -1e-6)
			if forward then
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
---@param opts { panes: table[], items: table[], cursor_block?: string, on_choose: fun(item: table|nil), on_switch?: fun() }
function M.select(opts)
	local panes = opts.panes or {}
	local items = opts.items or {}
	define_hl()

	local by_block = {}
	for i, it in ipairs(items) do
		it.letter = LETTERS[i]
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

	-- 只需要放一个字母，所以做成小块提示图：大约四分之一屏，再多也是空的
	local W = math.min(math.max(math.floor(vim.o.columns * 0.25 + 0.5), 12), 32)
	local H = math.min(math.max(math.floor(vim.o.lines * 0.20 + 0.5), 3), 9)

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
	local win
	-- 浮窗居中：用 UI 的真实尺寸而不是 vim.o.lines。vim.o.lines 含底部的命令行行，
	-- 而消息区/cmdline 高度变化时编辑器区域会跟着变，按 o.lines 算就会偏移。
	local function editor_size()
		local ui = api.nvim_list_uis()[1]
		if not ui then
			return vim.o.columns, vim.o.lines
		end
		return ui.width, ui.height - (vim.o.cmdheight or 1)
	end

	-- 每次重画都重新贴一次位置：命令行/消息区尺寸变化时，浮窗不该被推着走。
	local function place()
		if not (win and api.nvim_win_is_valid(win)) then
			return
		end
		local cols, rows = editor_size()
		pcall(api.nvim_win_set_config, win, {
			relative = "editor",
			row = math.max(0, math.floor((rows - H) / 2)),
			col = math.max(0, math.floor((cols - W) / 2)),
		})
	end

	--- 不在当前 window 里的候选：地图上没格子，用底部一行列出来（字母照样能按）
	local function outside_note()
		local located = {}
		for _, p in ipairs(panes) do
			located[p.block_id] = true
		end
		local out = {}
		for _, it in ipairs(items) do
			if it.letter and it.block_id and not located[it.block_id] then
				out[#out + 1] = it.letter .. " " .. (it.name or it.label or "?")
			end
		end
		if #out == 0 then
			return nil
		end
		return "窗口外：" .. table.concat(out, "  ")
	end

	local function repaint()
		local painted = paint(panes, by_block, W, H, sel, outside_note())
		local lines, segs, h = painted[1], painted[2], painted[3]
		hit = h
		vim.bo[buf].modifiable = true
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		place()
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

	local cols0, rows0 = editor_size()
	win = api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((rows0 - H) / 2)),
		col = math.max(0, math.floor((cols0 - W) / 2)),
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
	-- 光标要在格子之间走动，'scrolloff' 一介入浮窗就会自己滚（画布宽度 == 窗口高度，
	-- 滚动不会有空行，视觉上就成了「整块地图往上平移」）。关掉。
	vim.wo[win].scrolloff = 0
	vim.wo[win].sidescrolloff = 0
	api.nvim_set_current_win(win)

	local finished = false
	local function close(item, switch)
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
		if switch then
			if opts.on_switch then
				opts.on_switch()
			end
			return
		end
		if opts.on_choose then
			opts.on_choose(item)
		end
	end

	local function move_to(item)
		-- 落在格子的中间而不是「第一格」：来回移动时光标位置稳定
		local cells = {}
		for y, list in pairs(hit or {}) do
			for x, it in pairs(list) do
				if it == item then
					cells[#cells + 1] = { y, x }
				end
			end
		end
		if #cells == 0 then
			return false
		end
		table.sort(cells, function(a, b)
			if a[1] ~= b[1] then
				return a[1] < b[1]
			end
			return a[2] < b[2]
		end)
		local mid = cells[math.floor((#cells + 1) / 2)]
		pcall(api.nvim_win_set_cursor, win, { mid[1], mid[2] - 1 })
		return true
	end

	if sel then
		move_to(sel)
	end

	-- 当前格子（光标看不见，所以只靠高亮表达）：格子里没有候选时不算
	api.nvim_create_autocmd("VimResized", {
		group = api.nvim_create_augroup("AiMapPlace", { clear = true }),
		callback = place,
	})

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

	-- 按画面走：从光标所在格往外一格一格挪，遇到的第一个别的 pane 就是画面上的邻居。
	-- 这样浮层和它底下的 pane 能来回穿（按 rect 算「谁在我旁边」时，浮层的边全在被它
	-- 盖住的那块里面，两边互相看不见，就回不去了）。
	---@return table|nil item, integer|nil y, integer|nil x 跨进对方的第一格
	local function walk(dir)
		local dy = (dir == "j" and 1) or (dir == "k" and -1) or 0
		local dx = (dir == "l" and 1) or (dir == "h" and -1) or 0
		local cur = api.nvim_win_get_cursor(win)
		local y, x = cur[1], cur[2] + 1
		local from = hit and hit[y] and hit[y][x]
		while true do
			y, x = y + dy, x + dx
			if y < 1 or y > H or x < 1 or x > W then
				return nil
			end
			local item = hit and hit[y] and hit[y][x]
			if item and item ~= from then
				return item, y, x
			end
		end
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
	map("<Tab>", function()
		close(nil, true)
	end, "切到列表选择器")
	map("q", function()
		close(nil)
	end, "取消")
	map("<Esc>", function()
		close(nil)
	end, "取消")

	-- h/j/k/l：把高亮移到相邻的格子（不直接发送，回车才确认）
	for _, dir in ipairs({ "h", "j", "k", "l" }) do
		map(dir, function()
			-- 先按画面走；走不出画布时（整高的 pane 往上下走）再按 rect 找邻居
			local item, y, x = walk(dir)
			if not item then
				local pane = neighbour(panes, current_pane(), dir)
				item = pane and by_block[pane.block_id]
			end
			if item then
				sel = item
				if y then
					pcall(api.nvim_win_set_cursor, win, { y, x - 1 })
				else
					move_to(item)
				end
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
