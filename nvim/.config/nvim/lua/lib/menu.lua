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
-- 如 yanky 历史）；menu 是「贴着光标的小浮窗 + 序号列」的轻量选择（vim.ui.select 的默认外观）。
-- 需要预览的场合仍显式调 ui.picker，不要往这里加预览。
--
-- 用法：
--   vim.ui.select(items, { prompt = "Pick: ", format_item = tostring }, function(item) ... end)
--   （setup() 会接管 vim.ui.select；这里也导出同签名的 M.select）
--
-- 三种模式（跟 dropbar 的菜单一致：打开时是导航模式，不会一上来就吃字符）：
--   导航模式：j / <Down> / <C-n> 下移，k / <Up> / <C-p> 上移；gg 首项、G 末项；
--            1-9 直接选（只到 9）；<CR> 选当前；i 或 f 或 / 进入输入模式；
--            <C-g> 进入索引模式；? 打开按键帮助；Esc / q 取消。
--            （数字只在导航模式当快捷键，输入模式下它们是普通查询字符）
--   输入模式：字符进入查询（内建 matchfuzzypos，任何可打印字符，含中文），<BS> 退格，<C-u> 清空；
--            <C-g> 转入索引模式（在当前过滤结果里按序号定位）；
--            <CR> 选当前；j/k 这时是查询字符（上下移动用 <Down>/<Up> 或 <C-n>/<C-p>）；
--            Esc 只退回导航模式（查询保留），再按 Esc 才取消。
--   索引模式：<C-g> 打开，输入框变成「 # 12」，敲数字直接定位到第 N 项（选中行实时跟随，
--            越界时数字标红）；<CR> 确认、<BS> 删一位、<C-u> 清空、Esc 退回上一模式。
--            序号是全列表的位置参照，所以 1-9 之外的项也有了直达手段。
--   帮助浮窗：'?' 打开，任意键（含 Esc）收起；关菜单时一并关掉。
-- 每一行前面都有序号（右对齐到同一列，见 M.label_width）：它首先是一个位置参照——
-- 同一列表每行都带编号，不会出现「前 18 项有、之后没有」的割裂感；1-9 可直接选，
-- 其余靠索引模式（<C-g>）或过滤；输入/索引模式下序号会降为注释色，避免看起来像快捷键。
-- 列表超过 config.max_height 时只画一个视口，选中项始终在视口内（不做平滑滚动）；
-- 宽度在 config.min_width..config.width 之间随内容自适应，且至少容得下标题。
-- 浮窗自己把 scrolloff/sidescrolloff 归零，全局 scrolloff=8 不会把内容推上去留白。
-- 浮窗位置锚在**光标所在的屏幕行列**（不是行首）：长行折行 / 水平滚动时也不会错位。
-- 提示文本（prompt）显示在浮窗上边框中间；输入模式时列表下方**单独浮一个输入框**
-- （" ❯ " + 查询），跟 dropbar 的菜单一致。输入位置用一个 Cursor 高亮的格子画出来：
-- 浮窗里的真光标在部分终端/配置下根本不显示，不能只依赖它。
-- 颜色/图标：`vim.ui.select` 的契约只有 `format_item(item):string`，拿不到 per-item 高亮。
-- 这里接两条事实标准（都不改契约，只把既有信息用起来）：
--   1. `format_item` 返回**第二个值** `virt_text`：chunk 列表 `{ {text, hl_group}, ... }`
--      （dropbar 的 utils.menu 就是这么用的），以 'eol' 虚拟文本挂在条目行尾；
--   2. 条目本身是结构化 table（`name`/`text`/`label` + `icon`/`icon_hl`/`name_hl`，dropbar
--      symbol 的形状）且没给 format_item 时，按字段拆出图标与名称并分别挂高亮。
-- 需要真正的预览（整块彩色内容）请走 ui/picker，不要往这里加。
-- 动态状态：`opts.tick` 打开「动画模式」——菜单照旧阻塞读键，但读不到键时等一帧就重画，
-- `format_item(item, frame)` 的第二个参数是递增的帧号（0,1,2,…）。于是繁忙状态可以画
-- 旋转图标（与 LSP 进度那种 spinner 一样的思路），而不是只能贴一个静态符号。每帧会重新跑一次
-- 过滤（matchfuzzypos 只在这一小撮行上），所以动画开销落在「帧间隔」而不是按键响应上；不传 tick
-- 的菜单完全不进这条路径，行为与性能跟以前一致。
--
-- 给其它插件用的接口（都很小，不掺业务）：
--   opts.tick = 90 | true   true = 用 M.config.tick（默认 90ms）；数字 = 自定义帧间隔
--   format_item(item, frame) -> 第二参是帧号；frame 为 nil 的实现（telescope 等）当静态用
--   M.spinner(frames?) -> function(frame?, base?)  取帧助手：给静态 base 就在无帧时回退到它
--   M.frames                                        默认盲文帧，可整体替换
-- 例：
--   local spin = require("lib.menu").spinner()
--   vim.ui.select(items, {
--     tick = true,
--     format_item = function(it, frame) return spin(frame, it.busy and "◐" or "●") .. " " .. it.name end,
--   }, on_choice)

local api = vim.api
local fn = vim.fn

local M = {}

M.config = {
	width = 64, -- 浮窗最大宽度（列）
	min_width = 30, -- 浮窗最小宽度（列）：只有一两个字的条目也不该缩成一条缝
	max_height = 14, -- 视口最多显示多少项（超出后滚动）
	border = "rounded",
	tick = 90, -- 动画帧间隔（毫秒）：opts.tick = true 时用它
}

-- 默认 spinner 帧（盲文点阵，与 LSP 进度同类；任意等宽字符都行）
-- M.frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
M.frames= {
	"",
	"",
	"",
	"",
	"",
	"",
}

--- 取帧助手：spinner()(frame, base)。frame 为 nil（不支持的 picker / 静态场合）时回退到 base，
--- 没给 base 就用第一帧。frames 可自定义（任意等宽字符序列），自己留一份就行。
---@param frames? string[]
---@return fun(frame?: integer, base?: string): string
function M.spinner(frames)
	frames = frames or M.frames
	return function(frame, base)
		if type(frame) ~= "number" then
			return base or frames[1]
		end
		return frames[frame % #frames + 1]
	end
end

-- 同一时间只允许一个菜单：重复按键直接取消新请求，不再叠一层
M._busy = false

local ns = api.nvim_create_namespace("lib-menu")

-- 输入框前缀：❯ 是 3 字节，光标列按字节算（索引模式的 " # " 用 #prefix 算，不写死）
local INPUT_PREFIX = " ❯ "

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

---第 idx 项的标签：每一项都编号。
---编号是「位置参照」，也是 1-9 直接选与 <C-g> 索引模式的落点；不再用快捷键字母决定「有没有标签」，
---否则第 19 项往后会突然没有前缀，同一个列表前 18 行带数字、之后不带，看着像两个列表。
---@param idx integer
---@return string
function M.label(idx)
	return tostring(idx)
end

---标签列宽度：所有行右对齐到同一列，条目文本才会从同一列开始。
---最少 2 位（1..9 也占 2 格，滚动/过滤时文本列不会左右跳），超过 99 项自动变 3 位。
---@param total integer
---@return integer
function M.label_width(total)
	return math.max(2, #tostring(math.max(total, 1)))
end

--- 把 format_item 返回的第二值（virt_text chunk 列表）规整成 { {text, hl}, ... }
--- 接受 string[][]、字符串[]、或单个字符串（默认注释色）。换行压成空格：
--- 条目行高固定为 1 行，任何 chunk 里出现换行都会把后续条目挤下去。
---@param raw any
---@return string[][]
local function sanitize_virt(raw)
	if type(raw) == "string" then
		return { { raw:gsub("[\r\n]+", " "), "Comment" } }
	end
	if type(raw) ~= "table" then
		return {}
	end
	local out = {}
	for _, chunk in ipairs(raw) do
		local text, hl
		if type(chunk) == "string" then
			text = chunk
		elseif type(chunk) == "table" then
			text, hl = chunk[1], chunk[2]
		end
		if type(text) == "string" and text ~= "" then
			out[#out + 1] = { (text:gsub("[\r\n]+", " ")), type(hl) == "string" and hl or "Comment" }
		end
	end
	return out
end

--- 条目 -> 可显示文本 + 可选高亮信息
--- 优先用调用方的 format_item（其第二返回值当 virt_text）；没有时认结构化条目
--- （dropbar symbol 的 `icon`/`icon_hl`/`name`/`name_hl`），最后退回 tostring。
---@param item any
---@param format_item? fun(item: any): string, string[][]?
---@return { text: string, virt?: string[][], icon_len: integer, icon_hl?: string, name_hl?: string }
function M.describe(item, format_item, frame)
	local text, virt
	if format_item then
		text, virt = format_item(item, frame)
	end
	local out = { text = "", icon_len = 0 }
	if type(text) == "string" then
		out.text = text
	elseif type(item) == "table" then
		local name = item.name or item.text or item.label
		if type(name) == "string" then
			local icon = type(item.icon) == "string" and item.icon or ""
			out.text = icon .. name
			out.icon_len = #icon
			out.icon_hl = item.icon_hl
			out.name_hl = item.name_hl
		end
	end
	if out.text == "" then
		out.text = tostring(item)
		out.icon_len, out.icon_hl, out.name_hl = 0, nil, nil
	end
	if virt ~= nil then
		local chunks = sanitize_virt(virt)
		if #chunks > 0 then
			out.virt = chunks
		end
	end
	return out
end

---模糊过滤（Vim 自带 matchfuzzypos，返回命中位置用于高亮）
---@param items any[]
---@param query string
---@param format_item? fun(item: any, frame?: integer): string, string[][]?
---@param frame? integer 动画帧号（opts.tick 模式下由菜单递增）
---@return { item: any, idx: integer, text: string, positions: integer[], virt?: string[][], icon_len: integer, icon_hl?: string, name_hl?: string }[]
function M.filter(items, query, format_item, frame)
	local descs, texts = {}, {}
	for i, item in ipairs(items) do
		local d = M.describe(item, format_item, frame)
		descs[i] = d
		texts[i] = d.text
	end
	local out = {}
	local function push(idx, positions)
		local d = descs[idx]
		out[#out + 1] = {
			item = items[idx],
			idx = idx,
			text = d.text,
			positions = positions,
			virt = d.virt,
			icon_len = d.icon_len,
			icon_hl = d.icon_hl,
			name_hl = d.name_hl,
		}
	end
	if query == "" then
		for i = 1, #items do
			push(i, {})
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
				push(idx, (packed[2] or {})[n] or {})
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
	for i = 1, #items do
		local text = texts[i]
		local s = text:lower():find(needle, 1, true)
		if s then
			local pos = {}
			local first = fn.strchars(text:sub(1, s - 1))
			for n = 0, needle_chars - 1 do
				pos[#pos + 1] = fn.byteidx(text, first + n)
			end
			push(i, pos)
		end
	end
	return out
end

---把一个菜单项渲染成一行文本（标签 + 内容）
---@param idx integer
---@param text string
---@param label_w? integer 标签列宽度（M.label_width）；省略则不补齐
---@return string
function M.line(idx, text, label_w)
	-- 条目文本里的换行会打破「一行一项」的假设（视口高度、选中行、命中高亮全按行号算），
	-- 统一压成空格，宁可长一点也不能让浮窗内容比视口多行
	text = text:gsub("[\r\n]+", " ")
	local label = M.label(idx)
	if label == "" then
		return text
	end
	if label_w and label_w > #label then
		label = string.rep(" ", label_w - #label) .. label
	end
	return label .. " " .. text
end

---按键帮助（? 打开）
M.help_entries = {
	{ "j / k, <Down>/<Up>", "move" },
	{ "<C-n> / <C-p>", "move" },
	{ "gg / G", "first / last item" },
	{ "1-9", "pick by number (navigation mode)" },
	{ "<C-g>", "typing number to jump to index" },
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
---索引模式（<C-g>）复用这个浮窗，前缀换成 " # "，内容是敲的数字。
---@param state table
local function render_input(state)
	local index_mode = state.mode == "index"
	if not (state.mode == "input" or index_mode or state.query ~= "") then
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

	local prefix = index_mode and " # " or INPUT_PREFIX
	local text = index_mode and state.num or state.query
	local line = prefix .. text .. " "
	-- 宽度与列表浮窗一致：两个浮窗左右边对齐，看起来是同一个面板
	local width = state.width or M.config.width
	-- 浮窗带边框：内容在 row，顶/底边框在 row-1 / row+1。
	-- 下面放得下（底边框不越过屏幕）就贴在菜单下方；否则对称地翻到菜单上方。
	-- render() 已经保证这两种摆法至少有一种成立（必要时会收窄菜单视口），
	-- 所以这里不需要再做钳制——钳制才是「输入框压住菜单边缘」的来源。
	local row = state.row + state.height + 2
	if row + 1 > vim.go.lines then
		row = state.row - 3
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
		-- 查询很长时也不要横向滚动（scrolloff 会把输入行推得看不见开头）
		for _, o in ipairs({ { "scrolloff", 0 }, { "sidescrolloff", 0 } }) do
			pcall(api.nvim_set_option_value, o[1], o[2], { win = state.input_win })
		end
		pcall(api.nvim_set_option_value, "scrolloffpad", 0, { win = state.input_win })
		api.nvim_set_option_value("winhl", "Normal:Pmenu,FloatBorder:FloatBorder", { win = state.input_win })
	else
		api.nvim_win_set_config(state.input_win, opts)
	end

	-- 前缀 " ❯ " 的 ❯ 在字节 1..3（索引模式的 " # " 只有一个字节）
	api.nvim_buf_set_extmark(
		state.input_buf,
		ns,
		0,
		1,
		{ end_col = index_mode and 2 or 4, hl_group = "lib-menu-label" }
	)
	local text_start = #prefix
	if index_mode and state.num ~= "" then
		-- 数字直接上色：越界（或 0）标红，用户不用按 <CR> 才知道敲错了
		local idx = tonumber(state.num)
		local ok_idx = idx ~= nil and idx >= 1 and idx <= #state.view
		api.nvim_buf_set_extmark(state.input_buf, ns, 0, text_start, {
			end_col = text_start + #state.num,
			hl_group = ok_idx and "lib-menu-index" or "lib-menu-error",
		})
	end
	local col_byte = text_start + #text
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
	local label_w = M.label_width(total)
	if total == 0 then
		lines[1] = state.query == "" and "  (empty)" or "  (no match)"
	end
	-- 视口：最多 max_height 行，选中项始终保持在视口内（不做平滑滚动）
	-- 终端本身装不下（窗口被压到很矮）时再按屏幕行数收窄：否则浮窗会越过屏幕下沿，
	-- nvim 只裁不缩，最后几项直接看不见
	local height = math.min(math.max(total, 1), math.max(1, M.config.max_height))
	height = math.min(height, math.max(1, vim.go.lines - 4))
	-- 输入框（输入/索引模式，或带查询的导航模式）是一个独立的 3 行浮窗：
	-- 上边框 + 一行内容 + 下边框。菜单的锚点行决定它能不能放得下：
	--   * 放在菜单下方：需要 row + height + 3 <= lines；
	--   * 翻到菜单上方：需要 row >= 5（内容在 row-3，上边框在 row-4）。
	-- 光标贴近屏幕顶端时菜单只能往下长，若不预留空间就会「下面放不下 → 翻到上面」
	-- 并压住菜单顶边框。这里只在这种情况下收窄视口，保证两种摆法至少有一种成立。
	if state.mode == "input" or state.mode == "index" or state.query ~= "" then
		for _ = 1, 3 do
			local row0 = math.max(1, math.min(state.pos.row, vim.go.lines - height - 1))
			if row0 + height + 3 <= vim.go.lines or row0 >= 5 then
				break
			end
			height = math.max(1, vim.go.lines - row0 - 3)
		end
	end
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
			lines[#lines + 1] = " " .. M.line(i, entry.text, label_w)
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

	-- 宽度自适应内容：测量**整个 view**而不是可见视口——只量视口的话，滚动时可见项的
	-- 标签宽度（1..n 的位数）会变，浮窗跟着一会儿变宽一会儿变窄。
	-- M.config.width 只是上限，超宽终端上菜单也不会拉成一条长条。
	-- 下限两道：min_width（条目太短时别缩成一条缝）与实际标题宽度 + 4（标题被截断
	-- 比留白更难看）。标题超长时仍以上限为准，交给 nvim 截断。
	local content_w = 0
	for i = 1, total do
		local entry = view[i]
		if entry then
			local w = fn.strdisplaywidth(" " .. M.line(i, entry.text, label_w))
			-- 行尾虚拟文本也要算进宽度，否则颜色/徽标会被浮窗边框裁掉
			if entry.virt then
				for _, chunk in ipairs(entry.virt) do
					w = w + 1 + fn.strdisplaywidth(chunk[1])
				end
			end
			content_w = math.max(content_w, w)
			if content_w >= M.config.width then
				break -- 已经到上限，不必再量
			end
		end
	end
	if total == 0 then
		content_w = fn.strdisplaywidth(lines[1] or "")
	end
	-- 标题（prompt）：换行会破坏浮窗边框，先压成空格
	local title = (state.prompt or ""):gsub("[\r\n]+", " ")
	local title_w = fn.strdisplaywidth(title)
	local want_w = math.max(content_w + 1, M.config.min_width or 1, title_w + 4)
	local width = math.min(M.config.width, want_w)
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
		title = title,
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
		-- 浮窗必须自己关掉 scrolloff / sidescrolloff / scrolloffpad：
		-- 本配置是全局 scrolloff=8（lua/boot/settings.lua:44），浮窗会继承它。
		-- 菜单内容永远刚好填满视口，光标往下走时 scrolloff 会为了留出「光标下方 8 行」
		-- 把整个内容向上推，于是浮窗底部出现一片空白、列表还少显示几项
		-- （终端里表现就是「滚到下面以后浮框下面空了」）。
		-- 与 lua/feat/terminal/sidebar.lua:409-412 的处理同理。
		for _, o in ipairs({ { "scrolloff", 0 }, { "sidescrolloff", 0 } }) do
			pcall(api.nvim_set_option_value, o[1], o[2], { win = state.win })
		end
		pcall(api.nvim_set_option_value, "scrolloffpad", 0, { win = state.win })
	else
		api.nvim_win_set_config(state.win, win_opts)
	end

	-- 标签与命中位置的高亮（行首一个空格 + 右对齐到 label_w 的编号 + 空格）
	-- 输入模式下编号只是位置参照（数字会被当成查询字符），压成注释色，免得看起来像快捷键
	local label_hl = (state.mode == "input" or state.mode == "index") and "lib-menu-label-dim" or "lib-menu-label"
	for n, text_line in ipairs(lines) do
		local entry = view[top + n - 1]
		if entry then
			local lnum = n - 1
			local label = M.label(top + n - 1)
			local text_start = label == "" and 1 or (2 + label_w)
			if label ~= "" then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, 1, {
					end_col = 1 + label_w,
					hl_group = label_hl,
				})
			end
			-- 条目自带的高亮（结构化条目的 icon/name，见 M.describe）：
			-- 它们相对 text_start 逐段挂，不影响下面的命中高亮
			local seg_start = text_start
			if (entry.icon_len or 0) > 0 then
				local icon_end = seg_start + entry.icon_len
				if entry.icon_hl then
					api.nvim_buf_set_extmark(state.buf, ns, lnum, seg_start, {
						end_col = math.min(#text_line, icon_end),
						hl_group = entry.icon_hl,
					})
				end
				seg_start = icon_end
			end
			if entry.name_hl then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, seg_start, {
					end_col = math.min(#text_line, seg_start + #entry.text - (entry.icon_len or 0)),
					hl_group = entry.name_hl,
				})
			end
			-- format_item 的第二返回值：附在行尾的虚拟文本（颜色/图标/补充信息）
			if entry.virt then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, 0, {
					virt_text = entry.virt,
					virt_text_pos = "eol",
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
---`tick` 为 nil/0 时照旧阻塞到有键为止；给了 tick 就最多等这么久，超时返回 nil（动画模式）。
---等待用 vim.wait：它跑事件循环，所以定时器/重画照常，菜单不会卡住整个 nvim。
---@param tick? integer 毫秒
---@return string|nil key nil 表示超时（或没有按键可读）
function M._read_key(tick)
	---立刻取一个键（typeahead），没有就返回 nil —— getcharstr(0) 不阻塞
	local function peek()
		local ok, key = pcall(fn.getcharstr, 0)
		if ok and type(key) == "string" and key ~= "" then
			return key
		end
		return nil
	end
	if not tick or tick <= 0 then
		local ok, key = pcall(fn.getcharstr)
		if not ok or type(key) ~= "string" or key == "" then
			return nil
		end
		return key
	end
	local key = peek()
	if key then
		return key
	end
	vim.wait(tick)
	return peek()
end

---打开选择菜单（vim.ui.select 兼容签名）
---@param items any[]
---@param opts? { prompt?: string, format_item?: fun(item:any):string, string[][]?, kind?: string }
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
		num = "", -- 索引模式的数字缓冲（<C-g>）
		mode = "normal", -- 打开时不进输入模式：j/k 上下，i/f 才输入
		formatted = opts.format_item,
		sel = 1,
		pos = anchor(),
		-- 动画模式（v1: 只有 opts.tick 一来才开）：帧号每超时一次 +1，传给 format_item
		tick = (opts.tick == true and M.config.tick) or tonumber(opts.tick) or 0,
		frame = 0,
	}
	state.view = M.filter(items, state.query, state.formatted, state.frame)

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
		state.view = M.filter(items, state.query, state.formatted, state.tick > 0 and state.frame or nil)
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

	---索引模式：数字一变就让选中行跟上（空串/越界时保持原地，靠输入框标红提示）
	---@param st table
	local function follow_index(st)
		local idx = tonumber(st.num)
		if idx and idx >= 1 and idx <= #st.view then
			st.sel = idx
		end
	end

	local ok, err = pcall(function()
		while true do
			-- 窗口没了就别再画、也别再吃键
			if state.closed_externally or state.win == nil or not api.nvim_win_is_valid(state.win) then
				break
			end
			-- 动画模式：每帧用新帧号重跑一次过滤（spinner 字符就是在 format_item 里按帧号取的）
			if state.tick > 0 then
				state.view = M.filter(items, state.query, state.formatted, state.frame)
			end
			render(state)
			local key = M._read_key(state.tick > 0 and state.tick or nil)
			if key == nil then
				if state.tick <= 0 then
					break -- 阻塞读键拿到 nil：没有可读的键了，按取消处理
				end
				-- 超时一帧：只推进帧号，下一轮重画；不处理按键（也不算作废 gg 的前置状态）
				state.frame = state.frame + 1
				state.pending_g = false
			else
				-- 读键期间窗口可能已经被关掉（WinClosed 会塞一个 Esc 解除阻塞），一律按取消处理
				if state.closed_externally or state.win == nil or not api.nvim_win_is_valid(state.win) then
					break
				end
				local k = fn.keytrans(key)
				local kl = k:lower() -- 特殊键 keytrans 可能大写（<C-N>）
				-- gg 的前置状态：只在「下一个键也是 g」时成立，其它任何键都会把它作废
				-- （与 Vim 一致，无超时；gj 就是普通的下移）
				local waiting_g = state.pending_g
				state.pending_g = false

				if kl == "<esc>" or kl == "<c-c>" then
					if state.help then
						state.help = false -- 帮助开着：先收帮助
					elseif state.mode == "input" or state.mode == "index" then
						state.mode = "normal" -- 输入/索引模式：只退回导航模式，不关菜单
						state.num = ""
					else
						break
					end
				elseif state.help then
					state.help = false -- 帮助开着时任何其他键都只收帮助
				elseif kl == "<cr>" or kl == "<nl>" then
					if state.mode == "index" then
						local idx = tonumber(state.num)
						if idx and pick(idx) then
							break
						elseif state.num == "" then
							state.mode = "normal" -- 空着按 <CR>：当作出索引模式，不选也不关菜单
						end
					-- 越界：留在索引模式，接着敲数字或 <Esc> 退出
					else
						pick(state.sel)
						break
					end
				elseif kl == "<down>" or kl == "<c-n>" then
					move(1)
				elseif kl == "<up>" or kl == "<c-p>" then
					move(-1)
				elseif kl == "<bs>" or kl == "<c-h>" then
					if state.mode == "index" then
						state.num = state.num:sub(1, -2) -- 只會有 ASCII 数字，按字节删安全
						follow_index(state)
					elseif state.query ~= "" then
						state.query = drop_last_char(state.query)
						refilter()
					end
				elseif kl == "<c-u>" then
					if state.mode == "index" then
						state.num = ""
					elseif state.query ~= "" then
						state.query = ""
						refilter()
					end
				elseif kl == "<c-g>" and state.mode ~= "index" then
					-- 导航/输入模式 → 索引模式：在**当前（可能已过滤的）结果**里按序号直达
					state.mode = "index"
					state.num = ""
				elseif state.mode == "normal" then
					-- 导航模式：只有命令键生效，其余可打印字符忽略（免得一按普通字母就进查询）
					if kl == "j" then
						move(1)
					elseif kl == "k" then
						move(-1)
					elseif k == "G" then
						-- 末项（shift-g；必须在 kl == "g" 之前判，否则会被当成 gg 的第一个 g）
						if #state.view > 0 then
							state.sel = #state.view
						end
					elseif kl == "g" then
						if waiting_g then
							if #state.view > 0 then
								state.sel = 1
							end
						else
							state.pending_g = true
						end
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
					end
				elseif state.mode == "index" then
					-- 索引模式：数字累加到要跳转的序号上，选中行实时跟随（越界时输入框里标红）
					if kl:match("^%d$") and #state.num < 6 then
						state.num = state.num .. kl
						follow_index(state)
					end
				elseif not is_special(k) then
					-- 输入模式：任何可打印字符（含中文等多字节）都进查询
					state.query = state.query .. k
					refilter()
				end
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
	api.nvim_set_hl(0, "lib-menu-label-dim", { link = "Comment", default = true })
	api.nvim_set_hl(0, "lib-menu-index", { link = "Number", default = true })
	api.nvim_set_hl(0, "lib-menu-error", { link = "DiagnosticError", default = true })
	api.nvim_set_hl(0, "lib-menu-match", { link = "Special", default = true })
end

return M
