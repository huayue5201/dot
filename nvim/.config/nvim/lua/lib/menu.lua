-- 基础模块：浮窗选择菜单（接管 vim.ui.select）。
--
-- 为什么自己写（而不是继续用 dropbar 的 vim.ui.select）：
--   * dropbar 的实现把菜单渲染绑在 bar/breadcrumb 的 symbol 类上，模糊匹配依赖
--     telescope-fzf-native 的 C 库（ffi + LuaJIT）；
--   * 它的 select 在取消（Esc）时**不回调** on_choice，而且重复触发会叠出第二层菜单。
-- 这里只要「菜单模式」这个外观，模糊匹配用 Vim 自带的 matchfuzzypos（零依赖），
-- 单飞（同一时间只有一个菜单）与取消语义在实现里就成立。
--
-- 与 ui/picker.lua 的分工：picker 是「底部整宽列表 + 右侧预览」的重型选择器（需要看文件内容时用，
-- 如 yanky 历史）；menu 是「贴着光标的小浮窗 + 数字标签」的轻量选择（vim.ui.select 的默认外观）。
-- 需要预览的场合仍显式调 ui.picker，不要往这里加预览。
--
-- 用法：
--   vim.ui.select(items, { prompt = "Pick: ", format_item = tostring }, function(item) ... end)
--   （setup() 会接管 vim.ui.select；这里也导出同签名的 M.select）
--
-- 两种模式（跟 dropbar 的菜单一致：打开时是导航模式，不会一上来就吃字符）：
--   导航模式：j / <Down> / <C-n> 下移，k / <Up> / <C-p> 上移；1-9 直接选，10 项以后 M-<pivot>；
--            （数字与 M-<pivot> 只在导航模式生效，输入模式下它们是普通查询字符）
--            <CR> 选当前；i 或 f 或 / 进入输入模式；? 打开按键帮助；Esc / q 取消。
--   输入模式：字符进入查询（内建 matchfuzzypos，任何可打印字符，含中文），<BS> 退格，<C-u> 清空；
--            <CR> 选当前；j/k 这时是查询字符（上下移动用 <Down>/<Up> 或 <C-n>/<C-p>）；
--            Esc 只退回导航模式（查询保留），再按 Esc 才取消。
--   帮助浮窗：'?' 打开，任意键（含 Esc）收起；关菜单时一并关掉。
-- 列表超过 config.max_height 时只画一个视口，选中项始终在视口内（不做平滑滚动）。
-- 浮窗位置锚在**光标所在的屏幕行列**（不是行首）：长行折行 / 水平滚动时也不会错位。
-- 提示文本（prompt）显示在浮窗上边框中间；输入模式时列表下方**单独浮一个输入框**
-- （" ❯ " + 查询），跟 dropbar 的菜单一致。输入位置用一个 Cursor 高亮的格子画出来：
-- 浮窗里的真光标在部分终端/配置下根本不显示，不能只依赖它。

local api = vim.api
local fn = vim.fn

local M = {}

M.config = {
	width = 64, -- 浮窗最大宽度（列）
	max_height = 14, -- 视口最多显示多少项（超出后滚动）
	border = "rounded",
	pivots = "asdfghjkl", -- 第 10 项起用 M-<pivot> 标签（与 dropbar 的肌肉记忆一致）
}

-- 同一时间只允许一个菜单：重复按键直接取消新请求，不再叠一层
M._busy = false

local ns = api.nvim_create_namespace("lib-menu")

-- 输入框前缀：❯ 是 3 字节，光标列按字节算
local INPUT_PREFIX = " ❯ "
local INPUT_PREFIX_BYTES = #INPUT_PREFIX

---keytrans 之后的特殊键（<CR>/<C-n>/<M-x> …）
---@param k string
---@return boolean
local function is_special(k)
	return #k > 2 and k:sub(1, 1) == "<" and k:sub(-1) == ">"
end

---删掉最后一个字符（多字节安全，不会把中文劈成非法 UTF-8）
---@param s string
---@return string
local function drop_last_char(s)
	local n = fn.strchars(s)
	if n <= 1 then
		return ""
	end
	return s:sub(1, fn.byteidx(s, n - 1))
end

---第 idx 项的标签
---@param idx integer
---@return string
function M.label(idx)
	if idx <= 9 then
		return tostring(idx)
	end
	local pivot = M.config.pivots:sub(idx - 9, idx - 9)
	if pivot == "" then
		return ""
	end
	return "M-" .. pivot
end

---模糊过滤（Vim 自带 matchfuzzypos，返回命中位置用于高亮）
---@param items any[]
---@param query string
---@param format_item? fun(item: any): string
---@return { item: any, idx: integer, text: string, positions: integer[] }[]
function M.filter(items, query, format_item)
	local fmt = format_item or tostring
	local texts = {}
	for i, item in ipairs(items) do
		texts[i] = fmt(item)
	end
	local out = {}
	if query == "" then
		for i, item in ipairs(items) do
			out[#out + 1] = { item = item, idx = i, text = texts[i], positions = {} }
		end
		return out
	end
	-- matchfuzzypos 在 Lua 里返回一个打包表：{ matches, positions, scores }
	-- matches 是命中的**文本**（已按分数排序），positions 是每个命中的 0-based 字节位置
	local ok_pos, packed = pcall(fn.matchfuzzypos, texts, query)
	if ok_pos and type(packed) == "table" and type(packed[1]) == "table" and #packed[1] > 0 then
		local used = {}
		for n, text in ipairs(packed[1]) do
			local idx
			for i = 1, #texts do
				if texts[i] == text and not used[i] then
					idx = i
					break
				end
			end
			if idx then
				used[idx] = true
				out[#out + 1] = { item = items[idx], idx = idx, text = text, positions = (packed[2] or {})[n] or {} }
			end
		end
		if #out > 0 then
			return out
		end
	end
	-- 兜底：大小写不敏感的子串匹配（matchfuzzypos 是大小写敏感的，查询里含大写时基本都会落到这里）
	-- positions 统一成 0-based 字节偏移（与 matchfuzzypos 一致），且只标字符起点——
	-- 逐字节标会把多字节字符切成半个字。
	local needle = query:lower()
	local needle_chars = fn.strchars(needle)
	for i, item in ipairs(items) do
		local text = texts[i]
		local s = text:lower():find(needle, 1, true)
		if s then
			local pos = {}
			local first = fn.strchars(text:sub(1, s - 1))
			for n = 0, needle_chars - 1 do
				pos[#pos + 1] = fn.byteidx(text, first + n)
			end
			out[#out + 1] = { item = item, idx = i, text = text, positions = pos }
		end
	end
	return out
end

---把一个菜单项渲染成一行文本（标签 + 内容）
---@param idx integer
---@param text string
---@return string
function M.line(idx, text)
	local label = M.label(idx)
	if label == "" then
		return text
	end
	return label .. " " .. text
end

---按键帮助（? 打开）
M.help_entries = {
	{ "j / k, <Down>/<Up>", "move" },
	{ "<C-n> / <C-p>", "move" },
	{ "1-9", "pick by number" },
	{ "M-<pivot>", "pick items 10+" },
	{ "<CR>", "accept" },
	{ "i / f / /", "type to filter (j/k become text)" },
	{ "<BS> / <C-u>", "delete char / clear query" },
	{ "<Esc>", "leave input mode, then close" },
	{ "?", "this help" },
}

---帮助浮窗的内容（等宽对齐）
---@return string[]
local function help_lines()
	local kw = 0
	for _, e in ipairs(M.help_entries) do
		kw = math.max(kw, #e[1])
	end
	local lines = { " Keys" }
	for _, e in ipairs(M.help_entries) do
		lines[#lines + 1] = " " .. e[1] .. string.rep(" ", kw - #e[1] + 2) .. e[2]
	end
	return lines
end

---帮助浮窗：开/关都走这里（state.help 决定是否显示）
---@param state table
local function render_help(state)
	if not state.help then
		if state.help_win and api.nvim_win_is_valid(state.help_win) then
			pcall(api.nvim_win_close, state.help_win, true)
		end
		state.help_win = nil
		return
	end

	local lines = help_lines()
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, fn.strdisplaywidth(l))
	end
	width = width + 1
	local height = #lines

	-- 优先放菜单右边，右边放不下就放左边
	local col = state.col + state.width + 2
	if col + width > vim.go.columns then
		col = state.col - width - 2
	end
	local row = math.min(state.row, math.max(1, vim.go.lines - height - 1))
	-- 左边保底：压到文本区起点左边就会盖住下面窗口的 statuscolumn
	col = math.max(state.left or 1, col)

	if state.help_buf == nil or not api.nvim_buf_is_valid(state.help_buf) then
		state.help_buf = api.nvim_create_buf(false, true)
		api.nvim_set_option_value("buftype", "nofile", { buf = state.help_buf })
	end
	api.nvim_set_option_value("modifiable", true, { buf = state.help_buf })
	api.nvim_buf_set_lines(state.help_buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = state.help_buf })

	local win_opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = M.config.border,
		title = " Help ",
		title_pos = "center",
		noautocmd = true,
	}
	if state.help_win == nil or not api.nvim_win_is_valid(state.help_win) then
		state.help_win = api.nvim_open_win(state.help_buf, false, win_opts)
		for _, o in ipairs({ { "statuscolumn", "" }, { "signcolumn", "no" }, { "foldcolumn", "0" }, { "wrap", false } }) do
			api.nvim_set_option_value(o[1], o[2], { win = state.help_win })
		end
		api.nvim_set_option_value(
			"winhl",
			"Normal:Pmenu,FloatBorder:FloatBorder,FloatTitle:Title",
			{ win = state.help_win }
		)
	else
		api.nvim_win_set_config(state.help_win, win_opts)
	end
end

---计算浮窗锚点：贴**光标所在的屏幕行列**（不是行首——长行折行、水平滚动时行首可能在别的
---屏幕行甚至不可见，按它摆会把菜单甩到别处）。
---@return { row: integer, col: integer }
local function anchor()
	local win = api.nvim_get_current_win()
	local cur = api.nvim_win_get_cursor(win)
	local pos = fn.screenpos(win, cur[1], cur[2] + 1)
	-- 文本区（越过 statuscolumn / number / sign 列）的起始屏幕列：
	-- 浮窗绝不能压到那里，否则 statuscolumn 上会留下残影
	local info = fn.getwininfo(win)[1]
	local textoff = info and info.textoff or 0
	local base = fn.win_screenpos(win)
	local left = (base[2] or 1) + textoff
	local row, col = pos.row, pos.col
	if row < 1 or col < 1 then
		-- 光标不在可视区（极端滚动 / 折行情况）：退回窗口文本区左上角
		row, col = math.max(1, base[1] or 1), left
	end
	return { row = row, col = math.max(left, col), left = left }
end

---输入框：独立的浮窗，贴在列表下方（跟 dropbar 的菜单一样，脱离列表单独浮着）。
---输入位置用 Cursor 高亮的格子画出来——浮窗里的真光标在部分终端/配置下根本不显示，
---只依赖它就会「看不见光标」；真光标正常时与这一格重合。
---@param state table
local function render_input(state)
	if not (state.mode == "input" or state.query ~= "") then
		if state.input_win and api.nvim_win_is_valid(state.input_win) then
			pcall(api.nvim_win_close, state.input_win, true)
		end
		state.input_win = nil
		-- 关掉当前窗口后焦点可能落到别的窗口：明确回菜单（按键循环还在菜单上）
		if state.win and api.nvim_win_is_valid(state.win) then
			pcall(api.nvim_set_current_win, state.win)
		end
		return
	end

	local line = INPUT_PREFIX .. state.query .. " "
	-- 宽度与列表浮窗一致：两个浮窗左右边对齐，看起来是同一个面板
	local width = state.width or M.config.width
	-- 列表带边框，下沿再留一行空；下面放不下就翻到列表上方
	local row = state.row + state.height + 2
	if row + 2 > vim.go.lines then
		row = math.max(1, state.row - 3)
	end
	local col = state.col

	if state.input_buf == nil or not api.nvim_buf_is_valid(state.input_buf) then
		state.input_buf = api.nvim_create_buf(false, true)
		api.nvim_set_option_value("buftype", "nofile", { buf = state.input_buf })
	end
	api.nvim_set_option_value("modifiable", true, { buf = state.input_buf })
	api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { line })
	api.nvim_set_option_value("modifiable", false, { buf = state.input_buf })
	api.nvim_buf_clear_namespace(state.input_buf, ns, 0, -1)

	local opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = 1,
		style = "minimal",
		border = M.config.border,
		noautocmd = true,
	}
	if state.input_win == nil or not api.nvim_win_is_valid(state.input_win) then
		state.input_win = api.nvim_open_win(state.input_buf, true, opts)
		for _, o in ipairs({ { "statuscolumn", "" }, { "signcolumn", "no" }, { "foldcolumn", "0" }, { "wrap", false } }) do
			api.nvim_set_option_value(o[1], o[2], { win = state.input_win })
		end
		api.nvim_set_option_value("winhl", "Normal:Pmenu,FloatBorder:FloatBorder", { win = state.input_win })
	else
		api.nvim_win_set_config(state.input_win, opts)
	end

	-- 前缀 " ❯ " 的 ❯ 在字节 1..3
	api.nvim_buf_set_extmark(state.input_buf, ns, 0, 1, { end_col = 4, hl_group = "lib-menu-label" })
	local col_byte = INPUT_PREFIX_BYTES + #state.query
	api.nvim_buf_set_extmark(state.input_buf, ns, 0, col_byte, {
		end_col = col_byte + 1,
		hl_group = "Cursor",
		priority = 210,
	})
	pcall(api.nvim_win_set_cursor, state.input_win, { 1, col_byte })
	-- 输入框是当前窗口：真光标（终端能显示时）就落在查询末尾
	pcall(api.nvim_set_current_win, state.input_win)
end

---@param state table
local function render(state)
	local view = state.view
	local total = #view
	local lines = {}
	if total == 0 then
		lines[1] = state.query == "" and "  (empty)" or "  (no match)"
	end
	-- 视口：最多 max_height 行，选中项始终保持在视口内（不做平滑滚动）
	local height = math.min(math.max(total, 1), math.max(1, M.config.max_height))
	local top = 1
	if total > 0 then
		local t = state.top or 1
		if state.sel < t then
			t = state.sel
		elseif state.sel >= t + height then
			t = state.sel - height + 1
		end
		top = math.max(1, math.min(t, total - height + 1))
		state.top = top
		for i = top, top + height - 1 do
			local entry = view[i]
			if not entry then
				break
			end
			lines[#lines + 1] = " " .. M.line(i, entry.text)
		end
	end
	height = #lines

	if state.buf == nil then
		state.buf = api.nvim_create_buf(false, true)
		-- buftype=nofile 让「浮窗专用」的 buffer 与普通文件区分开：
		-- statuscol.nvim 之类的 statuscolumn 提供者会据此清掉窗口的 statuscolumn
		-- （它们的 bt_ignore 默认就含 nofile），否则浮窗会继承
		-- %{%v:lua.require('statuscol')...%} 并按浮窗的行号污染下面窗口的缓存。
		api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
	end
	api.nvim_set_option_value("modifiable", true, { buf = state.buf })
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = state.buf })
	api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	-- 宽度自适应内容：lines 里已经含「行首空格 + 数字/M-<pivot> 标签 + 文本」，
	-- M.config.width 只是上限，超宽终端上菜单也不会拉成一条长条。
	-- 标题不算在内：prompt 往往很长（一到两行提示），拿它算会把菜单撑成满宽；
	-- 标题放不下时由 nvim 自己截断。
	local content_w = 0
	for _, l in ipairs(lines) do
		content_w = math.max(content_w, fn.strdisplaywidth(l))
	end
	local width = math.max(10, math.min(M.config.width, content_w + 1))
	local row = state.pos.row
	local col = state.pos.col
	-- 右/下边界钳制：nvim 不会因为浮窗出屏而报错，它只会静静地画在屏幕外。
	-- 钳制时先缩宽度、再挪列，且列不得小于文本区起点 left —— 否则浮窗会盖住下面
	-- 窗口的 statuscolumn / 行号列，菜单开着期间那里就多出一列深色竖纹。
	local left = state.pos.left or 1
	if left + width > vim.go.columns then
		width = math.max(1, vim.go.columns - left)
	end
	if col + width > vim.go.columns then
		col = math.max(left, vim.go.columns - width - 1)
	end
	state.left = left
	row = math.max(1, math.min(row, vim.go.lines - height - 1))
	-- 之后 input / help 浮窗都按菜单的实际位置摆（state.pos 只是光标锚点）
	state.row, state.col, state.height, state.width = row, col, height, width

	local win_opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = M.config.border,
		title = state.prompt,
		title_pos = "center",
		-- 关键：浮窗创建期间不要跑 autocmd。statuscol.nvim 的处理器用
		-- nvim_get_current_win() 定位窗口，浮窗创建时「当前窗口」还是下面那个，
		-- 于是它把 'statuscolumn' 设到了别的窗口上、并污染自己的每窗口缓存
		-- （表现为下面窗口的 statuscolumn 多出一列折叠符 / 深色竖纹残影）。
		noautocmd = true,
	}
	if state.win == nil or not api.nvim_win_is_valid(state.win) then
		state.origin_win = api.nvim_get_current_win()
		-- 开/关菜单都**不要**动原窗口的任何窗口选项（尤其 'cursorline'）：
		-- 改一个窗口选项会让整个窗口重画，菜单一关就是一次整屏闪烁
		-- （实测 14 249 B / 全 30 行）。原来这里为了「别让人以为光标还在原 buffer」
		-- 关掉 cursorline、close() 里再开回来，正是那次闪烁的来源，已删除。
		-- enter = true：成为当前窗口，终端才会在查询行画真光标（关窗时切回 origin_win）
		state.win = api.nvim_open_win(state.buf, true, win_opts)
		api.nvim_set_option_value("winhl", "Normal:Pmenu,FloatBorder:FloatBorder,FloatTitle:Title", { win = state.win })
		api.nvim_set_option_value("wrap", false, { win = state.win })
		-- 浮窗必须清掉 statuscolumn / signcolumn / foldcolumn：
		-- statuscol.nvim 的 'statuscolumn' 是全局表达式 %{%v:lua...%}，浮窗也会继承它，
		-- 而它取的是 nvim_get_current_win()（浮窗不是当前窗口 → 按下面的窗口求值），
		-- 算出来的片段会污染下面窗口的缓存，留下一列深色竖纹。
		api.nvim_set_option_value("statuscolumn", "", { win = state.win })
		api.nvim_set_option_value("signcolumn", "no", { win = state.win })
		api.nvim_set_option_value("foldcolumn", "0", { win = state.win })
	else
		api.nvim_win_set_config(state.win, win_opts)
	end

	-- 标签与命中位置的高亮（行首一个空格 + 标签 + 空格；超过 M-<pivot> 范围的项没有标签）
	for n, text_line in ipairs(lines) do
		local entry = view[top + n - 1]
		if entry then
			local lnum = n - 1
			local label = M.label(top + n - 1)
			local text_start = label == "" and 1 or (2 + #label)
			if label ~= "" then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, 1, {
					end_col = 1 + #label,
					hl_group = "lib-menu-label",
				})
			end
			for _, pos in ipairs(entry.positions) do
				local col = text_start + pos
				if col < #text_line then
					api.nvim_buf_set_extmark(state.buf, ns, lnum, col, {
						end_col = col + 1,
						hl_group = "lib-menu-match",
						priority = 200,
					})
				end
			end
		end
	end
	-- 选中行用 extmark 铺满整行，不用浮窗自己的 'cursorline'：那样每次移动
	-- 都靠窗口选项变化来重画，且高亮行会多出一条与 extmark 不一致的竖线
	local sel_line = math.max(1, math.min(state.sel - top + 1, height))
	if lines[sel_line] then
		api.nvim_buf_set_extmark(state.buf, ns, sel_line - 1, 0, {
			end_col = #lines[sel_line],
			hl_group = "PmenuSel",
			hl_eol = true,
			priority = 50,
		})
	end
	pcall(api.nvim_win_set_cursor, state.win, { sel_line, 1 })
	render_input(state)
	render_help(state)
	-- 阻塞读键前必须显式刷一次：nvim 在等待输入时不会自动 flush 待处理的浮窗重绘，
	-- 少了这一句表现为「按了快捷键什么都没弹出」。
	pcall(vim.cmd, "redraw")
end

---@param state table
local function close(state)
	state.closing = true
	if state.aug then
		pcall(api.nvim_del_augroup_by_id, state.aug)
		state.aug = nil
	end
	if state.win and api.nvim_win_is_valid(state.win) then
		pcall(api.nvim_win_close, state.win, true)
	end
	-- 焦点回到原窗口：否则下面那个窗口会按「非当前窗口」渲染一帧
	if state.origin_win and api.nvim_win_is_valid(state.origin_win) then
		pcall(api.nvim_set_current_win, state.origin_win)
	end
	if state.input_win and api.nvim_win_is_valid(state.input_win) then
		pcall(api.nvim_win_close, state.input_win, true)
	end
	state.input_win = nil
	if state.help_win and api.nvim_win_is_valid(state.help_win) then
		pcall(api.nvim_win_close, state.help_win, true)
	end
	state.help_win = nil
	-- 三个 scratch buffer 一起释放，不然每开一次菜单就漏一个隐藏 buffer
	-- （不能写成 ipairs({ state.buf, state.input_buf, state.help_buf })：中间有 nil 时 ipairs 会提前停）
	for _, field in ipairs({ "buf", "input_buf", "help_buf" }) do
		local buf = state[field]
		if buf and api.nvim_buf_is_valid(buf) then
			pcall(api.nvim_buf_delete, buf, { force = true })
		end
	end
	state.win, state.buf = nil, nil
	state.input_buf, state.help_buf = nil, nil
	-- close() 里只允许关窗 + 切回原窗口：**不要**再补 redraw!，也不要动原窗口
	-- 的任何窗口选项（'cursorline' 之类）——两者都会把整个窗口重画一遍，终端
	-- 闪一下，而且这一步发生在 on_choice 之前，正好卡在下一个浮窗弹出的瞬间。
	-- 历史上这两句都是「statuscolumn 留残影」的误修：真正的成因是浮窗越过 textoff
	-- 压住 statuscolumn + 浮窗自己用 cursorline + 建窗时跑 autocmd，现在分别由
	-- 21141dda（不越过 textoff）、选中行改成 extmark、noautocmd = true + 清空浮窗
	-- statuscolumn/signcolumn/foldcolumn 解决；关窗本身会把占过的区域置脏。
end

---读一个键（测试里可替换 M._read_key 来驱动菜单）
---@return string|nil
function M._read_key()
	local ok, key = pcall(fn.getcharstr)
	if not ok or type(key) ~= "string" or key == "" then
		return nil
	end
	return key
end

---打开选择菜单（vim.ui.select 兼容签名）
---@param items any[]
---@param opts? { prompt?: string, format_item?: fun(item:any):string, kind?: string }
---@param on_choice? fun(item: any?, idx: integer?)
---@return boolean 是否真的打开了（已有菜单在开时返回 false）
function M.select(items, opts, on_choice)
	if M._busy then
		-- 已有菜单在开：这次请求直接取消，保证调用方一定能收到回调
		if on_choice then
			on_choice(nil, nil)
		end
		return false
	end
	if type(items) ~= "table" or #items == 0 then
		if on_choice then
			on_choice(nil, nil)
		end
		return false
	end
	opts = opts or {}

	local state = {
		prompt = opts.prompt or "Select: ",
		query = "",
		mode = "normal", -- 打开时不进输入模式：j/k 上下，i/f 才输入
		formatted = opts.format_item,
		sel = 1,
		pos = anchor(),
	}
	state.view = M.filter(items, state.query, state.formatted)

	M._busy = true

	-- 先画一次（建窗失败就直接退回原始实现，别静默吞掉请求）
	local rendered, render_err = pcall(render, state)
	if not rendered then
		if os.getenv("MENU_DEBUG") then
			print("menu render failed: " .. tostring(render_err))
		end
		M._busy = false
		close(state)
		if M.builtin then
			return M.builtin(items, opts, on_choice)
		end
		if on_choice then
			on_choice(nil, nil)
		end
		return false
	end

	-- 浮窗被外部关掉（:q、切 tab、别的插件关浮窗）时，循环还阻塞在读键上，
	-- 会变成"看不见的菜单"继续吃按键。这里监听 WinClosed 并塞一个 Esc 解除阻塞。
	state.aug = api.nvim_create_augroup("lib_menu_" .. tostring(state.win), { clear = true })
	api.nvim_create_autocmd("WinClosed", {
		group = state.aug,
		pattern = tostring(state.win),
		callback = function()
			if state.closing then
				return
			end
			state.closed_externally = true
			pcall(api.nvim_feedkeys, "\27", "n", false)
		end,
	})

	local function move(delta)
		if #state.view == 0 then
			return
		end
		state.sel = (state.sel - 1 + delta) % #state.view + 1
	end

	local function refilter()
		state.view = M.filter(items, state.query, state.formatted)
		state.sel = 1
		state.top = 1
	end

	---选中第 idx 项；idx 无效时返回 false
	local function pick(idx)
		local entry = state.view[idx]
		if not entry then
			return false
		end
		state.sel = idx
		state.choice = entry
		return true
	end

	local ok, err = pcall(function()
		while true do
			-- 窗口没了就别再画、也别再吃键
			if state.closed_externally or state.win == nil or not api.nvim_win_is_valid(state.win) then
				break
			end
			render(state)
			local key = M._read_key()
			if key == nil then
				break
			end
			-- 读键期间窗口可能已经被关掉（WinClosed 会塞一个 Esc 解除阻塞），一律按取消处理
			if state.closed_externally or state.win == nil or not api.nvim_win_is_valid(state.win) then
				break
			end
			local k = fn.keytrans(key)
			local kl = k:lower() -- 特殊键 keytrans 可能大写（<C-N>）

			if kl == "<esc>" or kl == "<c-c>" or kl == "<c-g>" then
				if state.help then
					state.help = false -- 帮助开着：先收帮助
				elseif state.mode == "input" then
					state.mode = "normal" -- 输入模式：只退回导航模式，不关菜单
				else
					break
				end
			elseif state.help then
				state.help = false -- 帮助开着时任何其他键都只收帮助
			elseif kl == "<cr>" or kl == "<nl>" then
				pick(state.sel)
				break
			elseif kl == "<down>" or kl == "<c-n>" then
				move(1)
			elseif kl == "<up>" or kl == "<c-p>" then
				move(-1)
			elseif kl == "<bs>" or kl == "<c-h>" then
				if state.query ~= "" then
					state.query = drop_last_char(state.query)
					refilter()
				end
			elseif kl == "<c-u>" then
				if state.query ~= "" then
					state.query = ""
					refilter()
				end
			elseif state.mode == "normal" then
				-- 导航模式：只有命令键生效，其余可打印字符忽略（免得一按普通字母就进查询）
				if kl == "j" then
					move(1)
				elseif kl == "k" then
					move(-1)
				elseif kl == "q" then
					break
				elseif kl == "i" or kl == "f" or kl == "/" then
					state.mode = "input"
				elseif kl == "?" then
					state.help = true
				elseif kl:match("^%d$") then
					if pick(tonumber(kl)) then
						break
					end
				elseif kl:match("^<m%-(%a)>$") then
					local slot = M.config.pivots:find(kl:match("^<m%-(%a)>$"), 1, true)
					if slot and pick(slot + 9) then
						break
					end
				end
			elseif not is_special(k) then
				-- 输入模式：任何可打印字符（含中文等多字节）都进查询
				state.query = state.query .. k
				refilter()
			end
		end
	end)
	pcall(close, state)
	M._busy = false
	if not ok then
		error(err, 0)
	end
	if on_choice then
		if state.choice then
			on_choice(state.choice.item, state.choice.idx)
		else
			on_choice(nil, nil)
		end
	end
	return true
end

---接管 vim.ui.select（保存原始实现到 M.builtin，便于临时回退）
---@param opts? table
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end
	if not M.builtin then
		M.builtin = vim.ui.select
	end
	vim.ui.select = function(items, o, on_choice)
		M.select(items, o, on_choice)
	end
	api.nvim_set_hl(0, "lib-menu-label", { link = "Identifier", default = true })
	api.nvim_set_hl(0, "lib-menu-match", { link = "Special", default = true })
end

return M
