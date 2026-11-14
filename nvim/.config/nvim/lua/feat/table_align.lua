-- lua/feat/table_align.lua
---@brief markdown 表格的「就地对齐」：像 org-mode 一样，改完表格就把这个表重排整齐
--
-- 为什么自己写（而不是 render-markdown / prettier / deno fmt）：
--   * render-markdown 的表格是 extmark 画框（parser 457 + render 328 行），并且它按「整篇
--     文档」重渲染：172KB 的 md 每次光标移动 ~66ms（见 2026-11-12 的实测）。这里只碰
--     pipe_table 节点覆盖的那几行，成本 O(表格行数)。
--   * prettier 根本不按列 pad；deno fmt（dprint）能算对 CJK 宽度，但分隔行和右对齐列的
--     输出是坏的（`---:` 被压成 `-:`）。都比不上自己 100 行。
--   * 对齐后的源码本身就是整齐的表：可复制、diff 只落在表格块内、别的编辑器打开也齐。
--
-- 行为：
--   * 触发：nvim_buf_attach 的 on_lines（任何来源的改动都算，含 API / 插件写入），
--     debounce 60ms；InsertLeave 立刻结算。插入模式默认不写回 —— 改「正在编辑的
--     那一行」会和 nvim 的插入状态打架（实测吞按键、把字符写到别处），
--     config.live_insert 可开成「只对齐别的行」。
--   * 打开文件：只对齐「视口里的表」（BufWinEnter 一次，±5 行），不扫全篇 ——
--     大文件也只有一次 treesitter parse + 按行范围剪枝遍历，实测视口 22 行 0.12ms
--     （冷启动 0.6ms）。文件本来是干净的就把 modified 复位，不做「打开就变脏」。
--     屏幕外/之后滚进来的表不动（源码在滚动时自己变太惊悚），要整理全篇用 :TableAlign!
--   * 手动：:TableAlign（光标所在表）/ :TableAlign!（整篇所有表）
--   * 跳过：非 markdown、buftype ~= ""、not modifiable、
--     vim.b[buf].table_align_disabled = true
--   * 幂等：新行和旧行一样就不写回 —— 否则自己的修改会再触发 TextChanged，无限循环。
--   * 光标：重排后按「第几个单元格 + 单元格内字节偏移」重新定位，打字时不会跳。
--   * 方向：GFM 分隔行（---: / :--- / :---:），CJK 用 strdisplaywidth 算显示宽度。

local M = {}

M.config = {
	debounce = 60,
	filetypes = { markdown = true },
	enabled = true,
	-- 插入模式里是否也对齐。默认关：写回「正在编辑的那一行」会和 nvim 的插入状态打架
	-- （实测会吞按键、把字符写到别处、把光标乱塞），所以只在离插入模式时结算。
	-- 打开后插入模式只对齐「别的行」，光标所在行仍留给 InsertLeave。
	live_insert = false,
	-- 行数上限：超过就跳过。本机实测 6800 行的巨型「表格」（CSV 被当成 pipe_table）
	-- 单次重排 17.8ms；正常文档里的表都远小于这个数，这里只是防止病态输入卡住
	max_rows = 200,
}

local query ---@type vim.treesitter.Query?

local timers = {} ---@type table<integer, uv_timer_t>
local applying = {} ---@type table<integer, boolean>

---@param buf integer
---@return boolean
local function is_enabled(buf)
	if not M.config.enabled or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		return false
	end
	if not M.config.filetypes[vim.bo[buf].filetype] then
		return false
	end
	if vim.bo[buf].buftype ~= "" or vim.bo[buf].readonly or not vim.bo[buf].modifiable then
		return false
	end
	if vim.b[buf].table_align_disabled == true then
		return false
	end
	return true
end

---markdown 的 pipe_table 查询（缓存，解析器缺失时返回 nil）
---@return vim.treesitter.Query?
local function table_query()
	if query ~= nil then
		return query
	end
	local ok, q = pcall(vim.treesitter.query.parse, "markdown", "(pipe_table) @table")
	query = ok and q or false
	return ok and q or nil
end

---反引号行内代码段的结束位置（未闭合返回 nil）
---@param line string
---@param i integer 起始反引号位置
---@return integer? 结束反引号位置（含）
local function code_span_close(line, i)
	local run = line:match("^`+", i)
	if not run then
		return nil
	end
	local n, from = #run, i + #run
	while true do
		local s, e = line:find("`+", from)
		if not s then
			return nil
		end
		if e - s + 1 == n then
			return e
		end
		from = e + 1
	end
end

---一行拆成单元格：按未转义、且不在行内代码里的 `|` 切分，
---并记录「去掉首尾空白后的内容」的起始字节列
---@param line string
---@return { text: string, col: integer }[]
local function parse_row(line)
	local segs = {}
	local i, start, n = 1, 1, #line
	while i <= n do
		local c = line:sub(i, i)
		if c == "\\" then
			i = i + 2 -- 跳过 `\|` 这种转义
		elseif c == "`" then
			-- 行内代码里的 `|` 是内容不是列分隔（`` `a | b` `` 常见于命令表）
			local close = code_span_close(line, i)
			if close then
				i = close + 1
			else
				i = i + #(line:match("^`+", i) or "`") -- 未闭合的反引号当普通字符
			end
		elseif c == "|" then
			segs[#segs + 1] = { s = start, e = i - 1 }
			start = i + 1
			i = i + 1
		else
			i = i + 1
		end
	end
	segs[#segs + 1] = { s = start, e = n }

	local cells = {}
	for idx, seg in ipairs(segs) do
		local text = line:sub(seg.s, seg.e)
		local pad = #(text:match("^%s*") or "")
		cells[idx] = {
			text = text:match("^%s*(.-)%s*$") or text,
			col = seg.s + pad,
		}
	end
	-- 首尾的空段来自外框竖线（`| a | b |` 切出来是 ""、a、b、""）
	if #cells > 1 and cells[1].text == "" then
		table.remove(cells, 1)
	end
	if #cells > 1 and cells[#cells].text == "" then
		table.remove(cells)
	end
	return cells
end

---GFM 分隔行单元格的对齐方向
---@param text string
---@return "left"|"right"|"center"|nil
local function align_of(text)
	if text:find("^:.*:$") then
		return "center"
	end
	if text:match("^:") then
		return "left"
	end
	if text:match(":$") then
		return "right"
	end
	return nil
end

---@param text string
---@param width integer
---@param align "left"|"right"|"center"|nil
---@return string
local function pad(text, width, align)
	local fill = width - vim.fn.strdisplaywidth(text)
	if fill <= 0 then
		return text
	end
	if align == "right" then
		return string.rep(" ", fill) .. text
	elseif align == "center" then
		local left = math.floor(fill / 2)
		return string.rep(" ", left) .. text .. string.rep(" ", fill - left)
	end
	return text .. string.rep(" ", fill)
end

---分隔行单元格：用 `-` 填满宽度，冒号留在对齐那一侧
---@param align "left"|"right"|"center"|nil
---@param width integer
---@return string
local function delimiter_cell(align, width)
	width = math.max(width, 3)
	if align == "center" then
		return ":" .. string.rep("-", math.max(width - 2, 1)) .. ":"
	elseif align == "left" then
		return ":" .. string.rep("-", math.max(width - 1, 2))
	elseif align == "right" then
		return string.rep("-", math.max(width - 1, 2)) .. ":"
	end
	return string.rep("-", width)
end

---把一个表的若干行重排；行数不变（纯粹的行内重排）
---@param lines string[]
---@return string[]?
local function align_table_lines(lines)
	if #lines < 2 then
		return nil
	end
	local rows = {}
	for i, line in ipairs(lines) do
		rows[i] = parse_row(line)
	end
	-- 第 2 行是分隔行；它的单元格只用来取对齐方向，不参与列宽计算
	local aligns = {}
	for c, cell in ipairs(rows[2] or {}) do
		aligns[c] = align_of(cell.text)
	end
	local ncols = 0
	for _, row in ipairs(rows) do
		ncols = math.max(ncols, #row)
	end
	if ncols == 0 then
		return nil
	end

	local widths = {}
	for i, row in ipairs(rows) do
		if i ~= 2 then
			for c = 1, ncols do
				local cell = row[c]
				local w = cell and vim.fn.strdisplaywidth(cell.text) or 0
				if w > (widths[c] or 0) then
					widths[c] = w
				end
			end
		end
	end
	for c = 1, ncols do
		widths[c] = math.max(widths[c] or 0, 3)
	end

	local out = {}
	for i, row in ipairs(rows) do
		local parts = {}
		for c = 1, ncols do
			if i == 2 then
				parts[c] = delimiter_cell(aligns[c], widths[c])
			else
				local cell = row[c]
				parts[c] = pad(cell and cell.text or "", widths[c], aligns[c])
			end
		end
		out[i] = "| " .. table.concat(parts, " | ") .. " |"
	end
	return out
end

---光标所在单元格：返回单元格序号与单元格内字节偏移
---@param cells { text: string, col: integer }[]
---@param col integer
---@return integer idx, integer offset
local function cell_at(cells, col)
	local idx = 1
	for i, cell in ipairs(cells) do
		if col >= cell.col then
			idx = i
		end
	end
	local cell = cells[idx]
	local offset = math.max(col - (cell and cell.col or col), 0)
	if cell then
		offset = math.min(offset, #cell.text)
	end
	return idx, offset
end

---重排 [first, last]（0-based，含）这几行；返回是否有改动
---@param buf integer
---@param first integer
---@param last integer
---@param keep_cursor boolean
---@param skip_row integer? 0-based 绝对行号：这一行不写回（插入模式正在编辑的那行不能碰）
---@return boolean
local function align_range(buf, first, last, keep_cursor, skip_row)
	if applying[buf] then
		return false
	end
	if first < 0 or last < first or last >= vim.api.nvim_buf_line_count(buf) then
		return false
	end
	if (last - first + 1) > M.config.max_rows then
		return false
	end

	local lines = vim.api.nvim_buf_get_lines(buf, first, last + 1, false)
	local new = align_table_lines(lines)
	if not new then
		return false
	end

	local changed = {}
	for i, line in ipairs(new) do
		if line ~= lines[i] and (first + i - 1) ~= skip_row then
			changed[#changed + 1] = i
		end
	end
	if #changed == 0 then
		return false
	end

	-- 光标定位：先记下「在第几个单元格的第几个字节」，写完再按新行找回来
	local win = vim.api.nvim_get_current_win()
	local cursor, cursor_cell, cursor_off
	if keep_cursor and vim.api.nvim_win_get_buf(win) == buf then
		local pos = vim.api.nvim_win_get_cursor(win)
		local row = pos[1] - 1
		if row >= first and row <= last then
			cursor = row - first
			cursor_cell, cursor_off = cell_at(parse_row(lines[cursor + 1]), pos[2])
		end
	end

	applying[buf] = true
	pcall(vim.cmd, "silent! undojoin") -- 并进当前 undo 块（打字时同一个 insert 段）
	for _, i in ipairs(changed) do
		vim.api.nvim_buf_set_lines(buf, first + i - 1, first + i, false, { new[i] })
	end
	applying[buf] = false

	if cursor then
		local cells = parse_row(new[cursor + 1])
		local cell = cells[cursor_cell]
		if cell then
			local col = cell.col + math.min(cursor_off, #cell.text)
			pcall(vim.api.nvim_win_set_cursor, win, { first + cursor + 1, col })
		end
	end
	return true
end

---收集 buffer 里所有的 pipe_table：{ first, last }（0-based，含）
---光标行所在的表节点（向上找 pipe_table），找不到返回 nil
---@param buf integer
---@param row integer
---@return vim.treesitter.Node?
local function table_at(buf, row)
	-- 必须先 parse 一次：buffer 还没解析过时 get_node 会返回 nil（实测）
	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
	if not parser_ok or not parser then
		return nil
	end
	if not pcall(parser.parse, parser) then
		return nil
	end
	local ok, node = pcall(vim.treesitter.get_node, {
		bufnr = buf,
		pos = { row, 0 },
		lang = "markdown",
	})
	if not ok or not node then
		return nil
	end
	while node do
		if node:type() == "pipe_table" then
			return node
		end
		node = node:parent()
	end
	return nil
end

---@param node vim.treesitter.Node
---@return integer, integer
local function node_rows(node)
	local sr, _, er, ec = node:range()
	-- 节点范围是半开区间：最后一行的下一个 0 列时 er 要减一
	return sr, (ec == 0) and (er - 1) or er
end

---@param buf integer
---@return { first: integer, last: integer }[]
local function tables(buf)
	local q = table_query()
	if not q then
		return {}
	end
	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
	if not parser_ok or not parser then
		return {}
	end
	local tree_ok, trees = pcall(parser.parse, parser)
	if not tree_ok or not trees or not trees[1] then
		return {}
	end
	local out = {}
	for _, node in q:iter_captures(trees[1]:root(), buf) do
		local sr, er = node_rows(node)
		out[#out + 1] = { first = sr, last = er }
	end
	return out
end

---0 表示当前 buffer
---@param buf integer
---@return integer
local function resolve(buf)
	return (buf == 0) and vim.api.nvim_get_current_buf() or buf
end

---对齐与 [first, last]（0-based，含）有交集的表
---
---用 get_node 从行往上找表，而不是每次都把整篇的 pipe_table 扫一遍：
---实测 3900 行的文档全篇 iter_captures 要 3.5ms，而定位一个表只要几十微秒。
---@param buf integer
---@param first integer
---@param last integer
---@param skip_edited boolean? 插入模式：写回时跳过光标所在行
---@return boolean
function M.align_rows(buf, first, last, skip_edited)
	buf = resolve(buf)
	if not is_enabled(buf) then
		return false
	end
	local skip_row
	local win = vim.api.nvim_get_current_win()
	if skip_edited and vim.api.nvim_win_get_buf(win) == buf then
		skip_row = vim.api.nvim_win_get_cursor(win)[1] - 1
	end
	local nrows = vim.api.nvim_buf_line_count(buf)
	-- 先把要动的表全找出来再写：一旦开始写，节点就失效了
	local ranges, seen = {}, {}
	for row = math.max(first, 0), math.min(last, nrows - 1) do
		-- 改动的行可能刚好变成空行/分隔行，左右各试一格
		for _, r in ipairs({ row, row + 1, row - 1 }) do
			if r >= 0 and r < nrows then
				local node = table_at(buf, r)
				if node then
					local sr, er = node_rows(node)
					local key = sr .. ":" .. er
					if not seen[key] then
						seen[key] = true
						ranges[#ranges + 1] = { sr, er }
					end
				end
			end
		end
	end
	local hit = false
	for _, r in ipairs(ranges) do
		hit = align_range(buf, r[1], r[2], true, skip_row) or hit
	end
	return hit
end

---对齐光标所在的那个表（找不到就什么都不做）
---@param buf integer
---@param skip_edited boolean? 插入模式：写回时跳过光标所在行
---@return boolean
function M.align_at_cursor(buf, skip_edited)
	buf = resolve(buf)
	if not is_enabled(buf) then
		return false
	end
	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_buf(win) ~= buf then
		return false
	end
	local row = vim.api.nvim_win_get_cursor(win)[1] - 1
	return M.align_rows(buf, row, row, skip_edited)
end

---对齐整篇所有表（倒序处理：行数不变，顺序其实无所谓，但保持稳定）
---@param buf integer
---@return integer 改动的表数
function M.align_all(buf)
	buf = resolve(buf)
	if not is_enabled(buf) then
		return 0
	end
	local n = 0
	for _, t in ipairs(tables(buf)) do
		if align_range(buf, t.first, t.last, false) then
			n = n + 1
		end
	end
	return n
end

---只收集与 [first, last]（0-based，含）相交的 pipe_table：parse 一次后按行范围剪枝遍历，
---不做全篇 iter_captures（3900 行文档要 3.5ms），也不逐行 get_node（视口 22 行约 1ms）
---@param buf integer
---@param first integer
---@param last integer
---@return { first: integer, last: integer }[]
local function tables_in_range(buf, first, last)
	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
	if not parser_ok or not parser then
		return {}
	end
	local ok, trees = pcall(parser.parse, parser)
	if not ok or not trees or not trees[1] then
		return {}
	end
	local out = {}
	local function walk(node)
		local sr, _, er = node:range()
		if er < first or sr > last then
			return
		end
		if node:type() == "pipe_table" then
			local r0, r1 = node_rows(node)
			out[#out + 1] = { r0, r1 }
			return
		end
		for child in node:iter_children() do
			walk(child)
		end
	end
	walk(trees[1]:root())
	return out
end

---对齐「当前视口内」的表（左右各留 margin 行，表的边可能在屏幕外）
---
---只处理与屏幕范围相交的表：不扫全篇、不调 tables(buf)（3900 行文档全篇 iter_captures
---要 3.5ms），定位靠 table_at 逐行向上找，命中一张就跳到它后面，视口通常只花几十~几百微秒。
---@param buf integer
---@param margin? integer
---@return integer 改动的表数
function M.align_visible(buf, margin)
	buf = resolve(buf)
	if not is_enabled(buf) then
		return 0
	end
	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_buf(win) ~= buf then
		return 0
	end
	local nrows = vim.api.nvim_buf_line_count(buf)
	margin = margin or 5
	local top = math.max(0, vim.fn.line("w0") - 1 - margin)
	local bottom = math.min(nrows - 1, vim.fn.line("w$") - 1 + margin)
	local n = 0
	-- 先收集再写：写 buffer 会让 treesitter 节点失效
	for _, t in ipairs(tables_in_range(buf, top, bottom)) do
		if align_range(buf, t[1], t[2], false) then
			n = n + 1
		end
	end
	return n
end

---@param buf integer
local function stop_timer(buf)
	local t = timers[buf]
	if t and t:is_active() then
		t:stop()
	end
end

---@type table<integer, { first: integer, last: integer }>
local pending = {}

---@param buf integer
---@param skip_edited boolean
---@param range { first: integer, last: integer }? 本次变更涉及的行
local function schedule(buf, skip_edited, range)
	if not is_enabled(buf) then
		return
	end
	if range then
		local p = pending[buf]
		if p then
			p.first = math.min(p.first, range.first)
			p.last = math.max(p.last, range.last)
		else
			pending[buf] = { first = range.first, last = range.last }
		end
	end
	local t = timers[buf]
	if not t then
		t = assert(vim.uv.new_timer())
		timers[buf] = t
	end
	t:stop()
	t:start(
		M.config.debounce,
		0,
		vim.schedule_wrap(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local p = pending[buf]
			pending[buf] = nil
			if p then
				M.align_rows(buf, p.first, p.last, skip_edited)
			else
				M.align_at_cursor(buf, skip_edited)
			end
		end)
	)
end

---@return boolean
local function in_insert()
	return vim.api.nvim_get_mode().mode:match("^[iR]") ~= nil
end

function M.setup()
	local group = vim.api.nvim_create_augroup("TableAlign", { clear = true })

	-- 进入 markdown buffer 时挂 buffer-local 的变更监听
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = vim.tbl_keys(M.config.filetypes),
		callback = function(args)
			local buf = args.buf
			-- 重载（:e!）时 b: 变量不会清空，这里手动复位，让视口对齐能再跑一次
			vim.b[buf].table_align_viewport = nil
			local bufgroup = vim.api.nvim_create_augroup("TableAlign_" .. buf, { clear = true })
			-- 用 nvim_buf_attach 而不是 TextChanged/TextChangedI：TextChanged 只反映
			-- 「普通模式里的编辑」，nvim_buf_set_text、插件写入、:g 等一律不触发（实测）；
			-- on_lines 是只要文本变了就一定来，还是增量通知（带改动行号）。
			vim.api.nvim_buf_attach(buf, false, {
				on_lines = function(_, b, _, first, _, last_new)
					if applying[b] then
						return
					end
					local range = { first = first, last = math.max(last_new or first, first) }
					-- on_lines 是 fast event：不能在这里直接改 buffer，只能排队
					vim.schedule(function()
						if not vim.api.nvim_buf_is_valid(b) then
							return
						end
						if in_insert() then
							-- 插入模式：默认什么都不写，等 InsertLeave 结算
							if M.config.live_insert then
								schedule(b, true, range)
							end
							return
						end
						schedule(b, false, range)
					end)
				end,
			})
			-- 离开插入模式时立刻结算：这是唯一写回「当前正在编辑的行」的时机
			vim.api.nvim_create_autocmd("InsertLeave", {
				group = bufgroup,
				buffer = buf,
				callback = function()
					stop_timer(buf)
					pending[buf] = nil
					M.align_at_cursor(buf)
				end,
			})
			vim.api.nvim_create_autocmd("BufWipeout", {
				group = bufgroup,
				buffer = buf,
				callback = function()
					stop_timer(buf)
					timers[buf] = nil
					applying[buf] = nil
					pending[buf] = nil
				end,
			})
		end,
	})

	-- 打开文件时对齐「视口里」的表：大文件也只花一次定位的钱，不扫全篇。
	-- 只跑一次 per buffer（vim.b 标记）；之后新滚进来的表靠编辑或 :TableAlign 处理。
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		callback = function(args)
			local buf = args.buf
			if not M.config.filetypes[vim.bo[buf].filetype] then
				return
			end
			if vim.b[buf].table_align_viewport then
				return
			end
			vim.b[buf].table_align_viewport = true
			-- 等这一轮事件走完：此时 w0/w$ 才是真正的视口
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(buf) or not is_enabled(buf) then
					return
				end
				local clean = not vim.bo[buf].modified
				if M.align_visible(buf) > 0 and clean then
					-- 只是补齐空白：文件本来就干净的话别让它变成「有未保存改动」
					vim.bo[buf].modified = false
				end
			end)
		end,
	})

	-- <leader>z 是工具分组（zm/zp/zx/zX/zz/zb/zs/zd/zw 已被占用）
	vim.keymap.set(
		"n",
		"<leader>za",
		"<cmd>TableAlign<cr>",
		{ silent = true, desc = "Markdown: 对齐光标所在的表" }
	)
	vim.keymap.set("n", "<leader>zA", "<cmd>TableAlign!<cr>", { silent = true, desc = "Markdown: 对齐整篇表格" })
	vim.keymap.set("x", "<leader>za", ":TableAlign<cr>", { silent = true, desc = "Markdown: 对齐选区里的表格" })

	vim.api.nvim_create_user_command("TableAlign", function(args)
		local buf = args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf()
		-- 给了范围（可视模式 <leader>za / :'<,'>TableAlign）就只动范围内的表
		if args.range == 2 then
			M.align_rows(buf, args.line1 - 1, args.line2 - 1)
			return
		end
		if args.bang then
			-- 整篇：批量整理已有文档就走这条（:argdo TableAlign! 可以跨文件）
			local n = M.align_all(buf)
			vim.notify(("TableAlign: 对齐了 %d 个表"):format(n), vim.log.levels.INFO)
		elseif not M.align_at_cursor(buf) then
			vim.notify("TableAlign: 光标不在表格里", vim.log.levels.WARN)
		end
	end, {
		bang = true,
		range = true,
		desc = "对齐 markdown 表格（!: 整篇；可视模式: 只动选区）",
	})
end

-- 测试用：内部函数
M._align_table_lines = align_table_lines
M._parse_row = parse_row
M._tables = tables

return M
