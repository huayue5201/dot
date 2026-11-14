-- lua/lsp_ext/features/hover.lua
---@brief 鼠标悬停浮窗：停稳后弹出「诊断 + LSP hover」，复刻 VSCode 的 hover 体验
---
---与已删除的 eagle.nvim 的差别（也是它体验不对的原因）：
---  * 不抢焦点：focusable = false + mouse = true，鼠标移进浮窗不切窗口、不动光标，
---    而事件又不会穿透到背后的代码（:h nvim_open_win 的 `mouse` 字段）。
---  * 不轮询：<MouseMove> 用 vim.on_key 观察（同 features/code_lens.lua），不装
---    <MouseMove>/<LeftMouse> 映射，不会遮蔽 bufferline 等插件的全局映射。
---  * 不自己排版：markdown 折行/宽度/边框/标题全交给
---    vim.lsp.util.open_floating_preview；诊断文本用
---    vim.diagnostic.config().float.format（与 grd 的诊断浮窗一致）。
---  * 不自己猜滚动：浮窗设 mouse = true，滚轮/点击由 nvim 原生处理，
---    不需要 hover_scroll 那套 nvim_win_call 兜底。
---  * 状态只有 { win, timer, seq, anchor }，没有互斥锁、没有 deep_equal 反查。
---
---行为：
---  鼠标停下 500ms 后弹；鼠标在同一个对象（anchor 范围）内移动 → 完全忽略，
---  不关窗、不清下划线、不重置计时、不重发请求；跑到别的对象上 → 立即关，
---  停稳后在新位置重弹（这就是 VSCode 的 hover 去抖方式）。
---  鼠标移进浮窗内部 → 保持（VSCode 行为）；移出 → 关闭。
---  鼠标所指对象的文本加下划线（highlight_symbol），hl_mode = "combine" 保留语法色。
---  浮窗内点击链接 → http(s) 交给 vim.ui.open，file:// 打开文件并定位。
---  诊断变化时若浮窗开着，原地重绘。
---键盘等价物 K：`vim.lsp.buf.hover` 本身被替换成 hover_via_render（Neovim 0.13 的
---buf.hover 不再经过 textDocument/hover handler，只换 handler 不生效），两条路共用
---同一套内容与窗口选项。表格是否按显示宽度对齐由 `M.config.render` 决定：
---  "native"（默认）markdown 原样交给 open_floating_preview，外观与原生 hover 一致；
---  "aligned" 过 md_render 转成对齐的纯文本，表格整齐但没有 markdown 高亮。
---注意 `vim.lsp.handlers["textDocument/hover"]` 并**没有**覆盖：0.13 里它只对显式调
---handler 的代码生效，覆盖反而会和 buf.hover 抢浮窗。
---
---定位：relative = "mouse"（nvim 原生支持），lsp/util.lua 的
---make_floating_popup_options 会自动做上下翻转，不需要 screenpos 换算。

local M = {}

local api = vim.api
local uv = vim.uv or vim.loop
local md_render = require("feat.md_render")

local ns = api.nvim_create_namespace("lsp_ext.hover_mouse")
local key_ns = api.nvim_create_namespace("lsp_ext.hover_mouse.keys")
local symbol_ns = api.nvim_create_namespace("lsp_ext.hover_mouse.symbol")

M.config = {
	delay = 500, -- 静止多久后弹（毫秒）
	max_height_factor = 2.5, -- 浮窗最大高度 = 屏幕行数 / factor
	border = "rounded",
	title = "", -- 空串 = 不要标题（VSCode 也没有）
	zindex = 60,
	show_diagnostics = true,
	show_hover = true,
	-- 浮窗外观：
	--  "hybrid"   — 默认。整份内容交给 open_floating_preview 按 markdown 渲染
	--               （treesitter 高亮 + conceal，与原生 K 同一个观感），
	--               只有表格块先做对齐（单元格内的反引号会被去掉，否则 conceal
	--               会把它们藏掉、列宽就对不齐）
	--  "native"   — 完全不动，markdown 原样渲染（表格不整齐）
	--  "aligned"  — 全篇过 feat.md_render 转成对齐的纯文本（最整齐，但没有高亮）
	render = "hybrid",
	-- 只在 native 下生效：长行折行。aligned 下一折行表格就错位，强制关闭。
	wrap = true,
	-- 鼠标停在空白（缩进/行尾）上：只有落在符号内（treesitter / 语义 token 覆盖）
	-- 才弹，和 VSCode 一致；关掉则行内任意位置都弹。
	require_symbol = true,
	-- 给鼠标所指对象的文本加下划线（hl_mode = "combine"，不盖掉语法色）
	highlight_symbol = true,
	symbol_hl = "HoverSymbol",
}

----------------------------------------------------------------------
-- 状态
----------------------------------------------------------------------

local state = {
	win = nil, ---@type integer? 浮窗 win
	buf = nil, ---@type integer? 浮窗 buf
	timer = nil, ---@type uv.uv_timer_t? 悬停延时
	seq = 0, -- 每次触发自增，用来丢弃过期的异步 hover 结果
	cancel = nil, ---@type function? 取消在飞的 hover 请求
	want = nil, -- 当前浮窗对应的鼠标位置（诊断变化时空位重绘）
	last = nil, -- 上一次鼠标位置，去重 <MouseMove> 洪水
	symbol_buf = nil, ---@type integer? 画了下划线的 buffer
	anchor = nil, ---@type table? 当前浮窗对应的对象范围 {buf, 1..4}，用于「同一个对象就不刷新」
}

---清掩「鼠标所指符号」的下划线
local function clear_symbol()
	local b = state.symbol_buf
	state.symbol_buf = nil
	if b and api.nvim_buf_is_valid(b) then
		pcall(api.nvim_buf_clear_namespace, b, symbol_ns, 0, -1)
	end
end

local function is_open()
	return state.win ~= nil and api.nvim_win_is_valid(state.win)
end

local function close()
	if is_open() then
		pcall(api.nvim_win_close, state.win, true)
	end
	state.win, state.buf, state.want = nil, nil, nil
	clear_symbol()
end

---关掉「K 浮窗」（open_floating_preview 认 focus_id，不是我们 state 里的鼠标浮窗）
local function close_hover_floats()
	for _, w in ipairs(api.nvim_list_wins()) do
		if vim.w[w]["textDocument/hover"] then
			pcall(api.nvim_win_close, w, true)
		end
	end
end

---浮窗外框（含 border）在屏幕上的矩形，1-based 行列，用于鼠标命中判定
local function float_rect()
	if not is_open() then
		return nil
	end
	local pos = api.nvim_win_get_position(state.win) -- 0-based，含 border
	local h = api.nvim_win_get_height(state.win)
	local w = api.nvim_win_get_width(state.win)
	return {
		top = pos[1] + 1,
		left = pos[2] + 1,
		bottom = pos[1] + h + 2, -- +1 border，+1 转 1-based
		right = pos[2] + w + 2,
	}
end

---鼠标是否停在浮窗上（VSCode 的「悬停粘住」行为靠这个）
local function mouse_in_float()
	local r = float_rect()
	if not r then
		return false
	end
	local m = vim.fn.getmousepos()
	return m.screenrow >= r.top and m.screenrow <= r.bottom and m.screencol >= r.left and m.screencol <= r.right
end

----------------------------------------------------------------------
-- 位置 / 文本判定
----------------------------------------------------------------------

---鼠标当前是否压在「普通窗口里的可见文本」上；返回 getmousepos() 结果或 nil
local function text_under_mouse()
	local m = vim.fn.getmousepos()
	if m.winid == 0 or m.line < 1 or m.column < 1 then
		return nil
	end
	-- 只要普通窗口：跳过浮窗、命令行、pum 之类
	local ok, cfg = pcall(api.nvim_win_get_config, m.winid)
	if not ok or cfg.relative ~= "" then
		return nil
	end
	local buf = api.nvim_win_get_buf(m.winid)
	if not api.nvim_buf_is_loaded(buf) then
		return nil
	end
	-- terminal / prompt / nofile（dashboard 等）不弹
	if vim.bo[buf].buftype ~= "" then
		return nil
	end
	local line = api.nvim_buf_get_lines(buf, m.line - 1, m.line, false)[1]
	if not line or m.column > #line then
		return nil -- 行尾之后
	end
	-- 位置可见性：被折叠/滚出屏幕时 screenpos 返回 0
	local sp = vim.fn.screenpos(m.winid, m.line, m.column)
	if sp.row == 0 then
		return nil
	end
	return m
end

---命中位置是否算「符号」：非空白字符，或落在 treesitter / 语义 token 范围内
----------------------------------------------------------------------
-- 命中判定 + 鼠标所指对象的范围
----------------------------------------------------------------------

local function is_word_char(c)
	-- 非空白、非 ASCII 标点；CJK 等多字节字符算「字」，下划线也算
	return c ~= "" and (c == "_" or not c:match("[%s%p]"))
end

---鼠标位置对应的「对象」。
---@return integer[]? range {sr, sc, er, ec}（0-based，end_col 独占）
---@return boolean on_symbol 是否值得弹浮窗（非空白字符，或被语义 token 覆盖）
---
---range 优先语义 token（就是高亮出来的那段），其次 treesitter 最小 capture，
---最后退回按字符扩展的「单词」（无 LSP 无 TS 的 buffer）。
local function locate(buf, row, col)
	local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	local ch = line:sub(col + 1, col + 1)
	local nonblank = ch ~= "" and ch:match("%S") ~= nil

	local ok, info = pcall(vim.inspect_pos, buf, row, col, { syntax = false })
	if not ok or type(info) ~= "table" then
		info = {}
	end

	---在候选里挑「包含 col 的单行、最短」的那段（最长 60 字节，防止整行/整语句）
	local function pick(items)
		local best
		for _, it in ipairs(items or {}) do
			local sr, sc = it.row, it.col
			local er, ec = it.end_row or it.row, it.end_col
			if sr == er and ec > sc and col >= sc and col < ec and ec - sc <= 60 then
				if not best or (ec - sc) < (best[4] - best[2]) then
					best = { sr, sc, er, ec }
				end
			end
		end
		return best
	end

	-- 落在空白上：treesitter 的 capture 范围会把缩进也算进去，只认语义 token
	local on_symbol = nonblank
		or not M.config.require_symbol
		or (info.semantic_tokens ~= nil and #info.semantic_tokens > 0)

	local range = pick(info.semantic_tokens) or pick(info.treesitter)
	if range then
		return range, on_symbol
	end

	-- 没有 LSP / treesitter：退回鼠标下的「单词」（按字符走，CJK 安全）
	local nchars = vim.fn.strchars(line)
	local cur = vim.fn.strchars(line:sub(1, col))
	local function c(i)
		return vim.fn.strcharpart(line, i, 1)
	end
	if not is_word_char(c(cur)) then
		return nil, on_symbol
	end
	local s, e = cur, cur
	while s > 0 and is_word_char(c(s - 1)) do
		s = s - 1
	end
	while e < nchars - 1 and is_word_char(c(e + 1)) do
		e = e + 1
	end
	return { row, vim.fn.byteidx(line, s), row, vim.fn.byteidx(line, e + 1) }, on_symbol
end

---两段范围是否相同（判断「还是同一个对象」）
local function same_range(a, b)
	return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

---位置 (row, col) 是否落在 range 内
local function in_range(range, row, col)
	return range ~= nil
		and row >= range[1]
		and row <= range[3]
		and (row > range[1] or col >= range[2])
		and (row < range[3] or col < range[4])
end

---给鼠标所指的符号加下划线。hl_mode = "combine" 只叠加下划线属性，保留语法色。
local function paint_symbol(want, range)
	clear_symbol()
	if not M.config.highlight_symbol or not want then
		return
	end
	local ok, buf = pcall(api.nvim_win_get_buf, want.winid)
	if not ok or not api.nvim_buf_is_valid(buf) then
		return
	end
	if not range then
		range = locate(buf, want.line - 1, want.column - 1)
	end
	if not range then
		return
	end
	local sr, sc, er, ec = range[1], range[2], range[3], range[4]
	local painted = pcall(api.nvim_buf_set_extmark, buf, symbol_ns, sr, sc, {
		end_row = er,
		end_col = ec,
		hl_group = M.config.symbol_hl,
		hl_mode = "combine",
		priority = 200,
	})
	if painted then
		state.symbol_buf = buf
	end
end

----------------------------------------------------------------------
-- 诊断
----------------------------------------------------------------------

local severity = vim.diagnostic.severity
local icons = require("lsp_ext.icons")
local severity_icon = {
	[severity.ERROR] = icons.ERROR,
	[severity.WARN] = icons.WARN,
	[severity.INFO] = icons.INFO,
	[severity.HINT] = icons.HINT,
}
---图标字形 → 高亮组（四个严重级别的字形不同，直接按字形反查）
local glyph_hl = {
	[icons.ERROR] = "DiagnosticError",
	[icons.WARN] = "DiagnosticWarn",
	[icons.INFO] = "DiagnosticInfo",
	[icons.HINT] = "DiagnosticHint",
}

---诊断范围是否覆盖 (row, col)；end_col 缺失/为 0 时按「起始列起一字节」处理
local function covers(d, row, col)
	local start_line = d.lnum or 0
	local end_line = d.end_lnum or start_line
	if row < start_line or row > end_line then
		return false
	end
	local start_col = d.col or 0
	local end_col = d.end_col
	if not end_col or end_col == 0 or end_col == start_col then
		end_col = start_col + 1
	end
	if row == start_line and col < start_col then
		return false
	end
	if row == end_line and col >= end_col then
		return false
	end
	return true
end

---该位置命中的诊断；没有精确命中就退回整行的诊断（VSCode 同款兜底）
local function diagnostics_at(buf, row, col)
	local all = vim.diagnostic.get(buf, { lnum = row })
	if #all == 0 then
		return {}
	end
	local hit = {}
	for _, d in ipairs(all) do
		if covers(d, row, col) then
			hit[#hit + 1] = d
		end
	end
	return #hit > 0 and hit or all
end

---复用 vim.diagnostic 的 float.format，没有就退回原始 message
---（float 配置可能是 true，表示用默认 handler，不是 table）
local function format_diagnostic(d)
	local cfg = (vim.diagnostic.config() or {}).float
	local fmt = type(cfg) == "table" and cfg.format or nil
	if type(fmt) == "function" then
		local ok, s = pcall(fmt, d)
		if ok and type(s) == "string" and #s > 0 then
			return s
		end
	end
	return d.message or ""
end

----------------------------------------------------------------------
-- hover
----------------------------------------------------------------------

---每个 client 用自己的 offset_encoding 换算位置（vim.pos 比手算 utf16 可靠）
local function hover_params(buf, row, col)
	return function(client)
		local enc = client.offset_encoding or "utf-16"
		local ok, pos = pcall(function()
			return vim.pos(buf, row, col):to_lsp(enc)
		end)
		return {
			textDocument = vim.lsp.util.make_text_document_params(buf),
			position = ok and pos or { line = row, character = col },
		}
	end
end

---把各家 client 的 hover 结果转成 markdown 行，按内容去重
local function collect_hover(results)
	local seen, out = {}, {}
	for _, resp in pairs(results) do
		local contents = resp and resp.result and resp.result.contents
		if contents then
			local ok, lines = pcall(vim.lsp.util.convert_input_to_markdown_lines, contents)
			if ok and lines and #lines > 0 then
				local key = table.concat(lines, "\n")
				if not seen[key] then
					seen[key] = true
					if #out > 0 then
						vim.list_extend(out, { "", "---", "" })
					end
					vim.list_extend(out, lines)
				end
			end
		end
	end
	return out
end

----------------------------------------------------------------------
-- 渲染
----------------------------------------------------------------------

---诊断图标上色。<MouseMove> 等场景下浮窗是 markdown + treesitter 渲染的，
---这里只给每行开头的图标补一个高优先级 extmark（不重排、不二次覆盖正文）。
local function paint_icons(buf)
	local i = 1
	for _, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
		for glyph, hl in pairs(glyph_hl) do
			if line:sub(1, #glyph) == glyph then
				pcall(api.nvim_buf_set_extmark, buf, ns, i - 1, 0, {
					end_col = #glyph,
					hl_group = hl,
					priority = 200,
				})
				break
			end
		end
		i = i + 1
	end
end

---把 hover 的 markdown 行变成「要显示的行」+ 配套的窗口选项。
---hybrid：只对齐表格块，其余行原样交给 open_floating_preview 做 markdown 渲染
---（treesitter、conceal、折叠空行、把 --- 展成 ─ 横线全由它处理），
---于是「原生外观」与「表格整齐」可以同时拿到；
---native：完全不动；aligned：全篇转纯文本，再关掉 conceal（否则被藏掉的 ` 会让
---对齐看起来错位）。
---@param lines string[]
---@return string[] shown, { wrap: boolean, conceallevel: integer }
local function present(lines)
	if M.config.render == "aligned" then
		return md_render.render_lines(lines), { wrap = false, conceallevel = 0 }
	end
	local shown = lines
	if M.config.render == "hybrid" then
		shown = md_render.render_lines(lines, { tables_only = true, strip_code = true })
	end
	return shown, { wrap = M.config.wrap ~= false, conceallevel = 2 }
end

---组装并打开浮窗。diags / hover 都可以为空，全空则不开。
local function render(diags, hover)
	local lines = {}

	for _, d in ipairs(diags or {}) do
		local icon = severity_icon[d.severity] or ""
		local first = true
		for _, l in ipairs(vim.split(format_diagnostic(d), "\n", { plain = true })) do
			-- 多行诊断的续行缩进两格，跟 VSCode 一样
			lines[#lines + 1] = first and (icon .. l) or ("  " .. l)
			first = false
		end
	end

	-- hover 是 markdown（sqls 之类会给整张表）：native 原样交给浮窗的 markdown
	-- 渲染（和原生 hover 一个外观），aligned 才先转成对齐的纯文本。
	-- 诊断不是 markdown，但混进同一个 buffer 后会被当作 markdown 排版，
	-- 所以折行/空行都自己保证（诊断文案里的 * _ ` 会被当作强调语法）。
	if hover and #hover > 0 then
		if #lines > 0 then
			vim.list_extend(lines, { "", "---", "" })
		end
		vim.list_extend(lines, hover)
	end

	if #lines == 0 then
		return
	end

	local shown, view = present(lines)
	if #shown == 0 then
		return
	end

	close()
	close_hover_floats()
	local title = M.config.title ~= "" and { { " " .. M.config.title .. " ", "Title" } } or nil
	-- 宽度不用自己算：open_floating_preview 内部按 strdisplaywidth 取内容最大宽度，
	-- 并用屏幕/窗口宽度封顶（runtime lua/vim/lsp/util.lua 的 _make_floating_popup_size）
	local ok, bufnr, winnr = pcall(vim.lsp.util.open_floating_preview, shown, "markdown", {
		relative = "mouse",
		anchor_bias = "below", -- 尽量出现在鼠标下方，空间不够自动翻上去
		focusable = false,
		border = M.config.border,
		title = title,
		max_height = math.floor(vim.o.lines / M.config.max_height_factor),
		zindex = M.config.zindex,
		-- 绑定源 buffer 的关闭事件（lsp/util.lua:1415）；光标移进浮窗不会触发
		close_events = { "CursorMoved", "CursorMovedI", "InsertEnter" },
	})
	if not ok or not winnr then
		return
	end

	-- mouse = true 让滚轮/点击作用在浮窗上而不是穿透到背后的代码；
	-- 配合 focusable = false，点一下不会把它变成「当前窗口」。
	pcall(api.nvim_win_set_config, winnr, { mouse = true })
	-- 已经按内容定宽；native 下按配置决定是否折行（可读性优先），
	-- aligned 下不能折行（会破坏表格）
	vim.wo[winnr].wrap = view.wrap
	vim.wo[winnr].conceallevel = view.conceallevel
	if view.conceallevel > 0 then
		vim.wo[winnr].concealcursor = "n"
	end
	-- treesitter markdown 的折叠会把这个浮窗里的段落藏起来
	vim.wo[winnr].foldenable = false
	vim.keymap.set("n", "<Esc>", close, { buffer = bufnr, silent = true, desc = "close hover" })

	state.win, state.buf = winnr, bufnr
	paint_icons(bufnr)
end

---渲染 + 打上符号下划线；内容全空（浮窗没开起来）就什么都不做
local function show(diags, hover, want, range)
	render(diags, hover)
	if is_open() then
		state.want = want
		state.anchor = {
			buf = api.nvim_win_get_buf(want.winid),
			range = range or (state.anchor and state.anchor.range),
		}
		paint_symbol(want, range)
	end
end

----------------------------------------------------------------------
-- 触发
----------------------------------------------------------------------

---真正去要数据。want = 触发时的 getmousepos() 快照
local function trigger(want)
	local m = vim.fn.getmousepos()
	if m.winid ~= want.winid or m.line ~= want.line or m.column ~= want.column then
		return -- 延时期间鼠标又动了（<MouseMove> 可能没送到），放弃
	end
	local buf = api.nvim_win_get_buf(want.winid)
	if not api.nvim_buf_is_loaded(buf) then
		return
	end
	local range, on = locate(buf, want.line - 1, want.column - 1)
	if not on or not range then
		close() -- 停在空白/没有对象的位置：收掉
		return
	end
	-- 还是在同一个对象上（浮窗已经开着）：什么都不做，不重发请求、不闪
	local a = state.anchor
	if is_open() and a and a.buf == buf and a.range and same_range(a.range, range) then
		state.want = want
		return
	end

	state.seq = state.seq + 1
	local seq = state.seq
	if state.cancel then
		pcall(state.cancel)
		state.cancel = nil
	end

	local diags = M.config.show_diagnostics and diagnostics_at(buf, want.line - 1, want.column - 1) or {}
	local has_hover = #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/hover" }) > 0
	if not M.config.show_hover or not has_hover then
		show(diags, nil, want, range)
		return
	end

	-- 诊断是本地数据，先出来；hover 回来再补齐（VSCode 也是渐进的）
	if #diags > 0 then
		show(diags, nil, want, range)
	end

	state.cancel = vim.lsp.buf_request_all(
		buf,
		"textDocument/hover",
		hover_params(buf, want.line - 1, want.column - 1),
		function(results)
			if seq ~= state.seq or not api.nvim_buf_is_valid(buf) then
				return
			end
			local hover = collect_hover(results)
			if #hover == 0 then
				return
			end
			-- 拿到结果时鼠标可能已经移走：再确认一次
			local now = vim.fn.getmousepos()
			if now.winid ~= want.winid or now.line ~= want.line or now.column ~= want.column then
				return
			end
			show(diags, hover, want, range)
		end
	)
end

local function start_timer()
	if not state.timer then
		return
	end
	state.timer:stop()
	state.timer:start(
		M.config.delay,
		0,
		vim.schedule_wrap(function()
			local m = vim.fn.getmousepos()
			if m.winid == 0 then
				return
			end
			trigger(m)
		end)
	)
end

local function stop_timer()
	if state.timer then
		state.timer:stop()
	end
end

----------------------------------------------------------------------
-- <MouseMove> / <LeftMouse> 观察
----------------------------------------------------------------------

---从点击列向两侧扩展出 token（链接），去掉尾部标点
local function token_at(line, col)
	local function ok_char(c)
		return c ~= "" and not c:match("[%s%(%)%[%]<>\"'`]")
	end
	local s, e = col + 1, col + 1
	while s > 1 and ok_char(line:sub(s - 1, s - 1)) do
		s = s - 1
	end
	while e <= #line and ok_char(line:sub(e, e)) do
		e = e + 1
	end
	return (line:sub(s, e - 1):gsub("[%.,;:]+$", ""))
end

local function open_file_link(url)
	local path, frag = url:match("^file://([^#]*)#?(.*)$")
	if not path or path == "" then
		return false
	end
	path = vim.uri_decode(path)
	if path == "" or vim.fn.filereadable(path) == 0 then
		return false
	end
	local lnum = tonumber(frag and frag:match("^L(%d+)")) or 1
	-- 当前 buffer 有未保存修改时 edit 会抛 E37；点链接不该失败
	local ok = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(path))
	if not ok then
		vim.notify("有未保存的修改，无法跳转到 " .. path, vim.log.levels.WARN)
		return false
	end
	pcall(api.nvim_win_set_cursor, 0, { lnum, 0 })
	return true
end

---浮窗内点击：找点击位置下的链接并打开
local function click_link()
	if not is_open() then
		return
	end
	local m = vim.fn.getmousepos()
	if m.winid ~= state.win then
		return
	end
	local line = api.nvim_buf_get_lines(state.buf, m.line - 1, m.line, false)[1]
	if not line then
		return
	end
	local token = token_at(line, m.column - 1)
	if token:match("^https?://") then
		vim.ui.open(token)
		close()
	elseif token:match("^file://") then
		if open_file_link(token) then
			close()
		end
	end
end

local mousemove_key = api.nvim_replace_termcodes("<MouseMove>", true, false, true)
local leftmouse_key = api.nvim_replace_termcodes("<LeftMouse>", true, false, true)

---on_key 里不能直接开关窗口（textlock），动作一律丢给 schedule
local function observer(key)
	if key == mousemove_key then
		local m = vim.fn.getmousepos()
		local last = state.last
		state.last = { m.winid, m.line, m.column, m.screenrow, m.screencol }
		if last and last[1] == state.last[1] and last[2] == state.last[2] and last[3] == state.last[3] then
			return -- 同一格反复触发，忽略
		end
		if vim.fn.mode() ~= "n" then
			return
		end
		-- 停在浮窗上：保持，别重置计时也别关
		if mouse_in_float() then
			stop_timer()
			return
		end
		if is_open() then
			-- 还在同一个对象范围内：直接忽略。横向移动同一个符号时
			-- 不关窗、不清下划线、不重置计时，更不重发 hover 请求。
			local a = state.anchor
			local ok, cur = pcall(api.nvim_win_get_buf, m.winid)
			if a and a.range and ok and a.buf == cur and in_range(a.range, m.line - 1, m.column - 1) then
				stop_timer()
				return
			end
			-- 换了对象/窗口：立刻收（schedule 里再判一次，防止期间鼠标又移回来）
			vim.schedule(function()
				if is_open() and not mouse_in_float() then
					close()
				end
			end)
			-- 不停在这里：挪到新对象上停下来要能重新弹（VSCode 也这样）
		end
		if not text_under_mouse() then
			stop_timer()
			return
		end
		start_timer()
	elseif key == leftmouse_key then
		if is_open() and mouse_in_float() then
			vim.schedule(click_link)
		end
	end
end

----------------------------------------------------------------------
-- setup
----------------------------------------------------------------------

---按内容宽度开一个只读 hover 浮窗（内建 K 与鼠标浮窗共用 render 配置的行渲染）
---@param lines string[]
---@param config? table
---@return integer? bufnr, integer? winnr
local function open_markdown_float(lines, config)
	local shown, view = present(lines)
	if #shown == 0 then
		return nil
	end
	local opts = vim.tbl_extend("force", {
		-- 必须是 focusable：open_floating_preview 只有在 focusable ~= false 且带
		-- focus_id 时才会在「同 focus_id 的浮窗已开」的情况下把光标送进去
		-- （再按一次 K 进浮窗滚动的原生行为靠的就是这个，鼠标浮窗才是 focusable=false）
		focusable = true,
		border = M.config.border,
		max_height = math.floor(vim.o.lines / M.config.max_height_factor),
	}, config or {})
	-- focus_id 是「这是个 LSP 浮窗」的标记：hover_scroll 靠它找窗口、再按一次 K 也靠它聚焦
	opts.focus_id = opts.focus_id or "textDocument/hover"
	local ok, bufnr, winnr = pcall(vim.lsp.util.open_floating_preview, shown, "markdown", opts)
	if not ok or not winnr then
		return nil
	end
	vim.wo[winnr].wrap = view.wrap
	vim.wo[winnr].conceallevel = view.conceallevel
	if view.conceallevel > 0 then
		vim.wo[winnr].concealcursor = "n"
	end
	vim.wo[winnr].foldenable = false
	-- 浮窗里再按 K 回到原窗口：core 只把 K 映射在源 buffer 上，浮窗里是空的
	pcall(vim.keymap.set, "n", "q", "<cmd>bdelete<cr>", {
		buffer = bufnr,
		silent = true,
		nowait = true,
		desc = "关闭 LSP 悬停浮窗",
	})
	pcall(vim.keymap.set, "n", "K", function()
		if api.nvim_win_get_config(0).relative ~= "" then
			vim.cmd("noautocmd wincmd p")
		end
	end, { buffer = bufnr, silent = true, desc = "离开 LSP 悬停浮窗" })
	return bufnr, winnr
end

---K（vim.lsp.buf.hover）也走同一套渲染
---
---为何要换函数而不只是换 handler：Neovim 0.13 的 `vim.lsp.buf.hover()` 自己收
---所有 client 的结果、自己调 open_floating_preview，**不再经过**
---`vim.lsp.handlers["textDocument/hover"]`（handler 只对显式调用 handler 的代码生效）。
---core 默认的 K 是 `function() vim.lsp.buf.hover() end`（runtime/lua/vim/lsp.lua），
---调用时才查字段，所以替换字段就能接管 K，且 client.lua 的 reset_defaults
---（比对 `keymap.callback == lsp.buf.hover`）也仍然成立。
local builtin_hover = vim.lsp.buf.hover

local function hover_via_render(opts)
	opts = opts or {}
	-- 已经站在自己的 hover 浮窗里：按 K 是「回去」，不是再请求一次
	local cur = api.nvim_get_current_win()
	if api.nvim_win_get_config(cur).relative ~= "" and vim.w[cur]["textDocument/hover"] then
		vim.cmd("noautocmd wincmd p")
		return
	end
	-- 鼠标浮窗还开着的话先收掉，否则两个浮窗会叠在一起
	close()
	local buf = api.nvim_get_current_buf()
	if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/hover" }) == 0 then
		return
	end
	vim.lsp.buf_request_all(buf, "textDocument/hover", function(client)
		-- 原生按 client 的 offset_encoding 算位置（与 vim.lsp.buf.hover 内部一致）
		return vim.lsp.util.make_position_params(cur, client.offset_encoding)
	end, function(results)
		if not api.nvim_buf_is_valid(buf) then
			return
		end
		-- 纯文本 hover 不是 markdown，交给原生 hover 原样显示（别让 md 渲染改它的文案）
		for _, r in pairs(results) do
			local c = r and r.result and r.result.contents
			if type(c) == "table" and c.kind == "plaintext" then
				close_hover_floats()
				return builtin_hover(opts)
			end
		end
		-- 与鼠标浮窗用同一套汇总逻辑（多 client 用 --- 分隔、按内容去重）
		local lines = collect_hover(results)
		if #lines == 0 then
			if opts.silent ~= true then
				vim.notify("No information available")
			end
			return
		end
		-- 原生 hover 会顺手高亮被悬停符号的范围（LspReferenceTarget），照做别丢
		local ns = api.nvim_create_namespace("nvim.lsp.hover_range")
		for _, r in pairs(results) do
			local res = r and r.result
			local client = r and api.nvim_get_current_buf() and vim.lsp.get_client_by_id(r.client_id)
			if res and res.range and client then
				pcall(function()
					local rng = vim.range.lsp(buf, res.range, client.offset_encoding)
					vim.hl.range(
						buf,
						ns,
						"LspReferenceTarget",
						{ rng.start_row, rng.start_col },
						{ rng.end_row, rng.end_col },
						{
							priority = vim.hl.priorities.user,
						}
					)
				end)
			end
		end
		local config = vim.tbl_extend("force", {}, opts)
		-- 每次重新取值：别的插件可能包了 hover，别把它们叠嵌套
		local _, winnr = open_markdown_float(lines, config)
		-- 浮窗关掉就把高亮清掉（与 runtime/lua/vim/lsp/buf.lua 一致）
		if winnr then
			api.nvim_create_autocmd("WinClosed", {
				pattern = tostring(winnr),
				once = true,
				callback = function()
					pcall(api.nvim_buf_clear_namespace, buf, ns, 0, -1)
				end,
			})
		end
		return winnr
	end)
end

function M.setup()
	if not vim.o.mousemoveevent then
		vim.o.mousemoveevent = true -- boot/settings.lua 已开，这里兜底
	end
	state.timer = state.timer or uv.new_timer()
	-- 接管 K：core 默认映射调用的是 vim.lsp.buf.hover 字段，运行时才取值
	vim.lsp.buf.hover = hover_via_render

	local group = api.nvim_create_augroup("LspExtHoverMouse", { clear = true })

	-- 只加下划线属性，前景色仍由语法高亮决定（extmark 用 hl_mode = "combine"）
	local function define_hl()
		api.nvim_set_hl(0, M.config.symbol_hl, { underline = true, default = true })
	end
	define_hl()
	api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = define_hl, -- :hi clear 会清掉，重设一次
	})

	-- 光标一挪，旧的下划线就没有意义了
	api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }, {
		group = group,
		callback = function(ev)
			if state.symbol_buf and (ev.event == "BufLeave" or ev.buf == state.symbol_buf) then
				clear_symbol()
			end
		end,
	})

	-- 任何「用户不该继续看旧浮窗」的动作都关掉
	api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			if not is_open() then
				return
			end
			close()
		end,
	})
	api.nvim_create_autocmd("WinScrolled", {
		group = group,
		callback = function()
			-- 鼠标在浮窗上时可能是在滚浮窗自身的内容，别关
			if is_open() and not mouse_in_float() then
				close()
			end
		end,
	})
	api.nvim_create_autocmd("TextChanged", {
		group = group,
		callback = function()
			if is_open() then
				close()
			end
		end,
	})

	-- 诊断变了：浮窗开着就原地重绘（VSCode 会实时更新）
	api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function(ev)
			local want = state.want
			if not is_open() or not want or api.nvim_win_get_buf(want.winid) ~= ev.buf then
				return
			end
			local diags = M.config.show_diagnostics and diagnostics_at(ev.buf, want.line - 1, want.column - 1) or {}
			local m = vim.fn.getmousepos()
			if m.winid ~= want.winid or m.line ~= want.line or m.column ~= want.column then
				return
			end
			local hover = {}
			if state.buf and api.nvim_buf_is_valid(state.buf) then
				-- 保留已有 hover 文本：从当前浮窗内容里取分隔线之后的部分
				local cur = api.nvim_buf_get_lines(state.buf, 0, -1, false)
				for i, l in ipairs(cur) do
					if l:match("^─+$") then
						hover = vim.list_slice(cur, i + 1)
						break
					end
				end
			end
			-- 首行可能有图标/空格，交给 render 重组，这里只去掉分隔线后的空行
			while #hover > 0 and vim.trim(hover[1]) == "" do
				table.remove(hover, 1)
			end
			if #diags == 0 and #hover == 0 then
				close()
				return
			end
			show(diags, hover, want, state.anchor and state.anchor.range)
		end,
	})

	-- 切到别的 app：没必要留着浮窗
	api.nvim_create_autocmd("FocusLost", {
		group = group,
		callback = function()
			if is_open() then
				close()
			end
		end,
	})

	vim.on_key(observer, key_ns)
end

return M
