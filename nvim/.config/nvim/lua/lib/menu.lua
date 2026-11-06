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
--            <CR> 选当前；i 或 f 或 / 进入输入模式；Esc / q 取消。
--   输入模式：字符进入查询（内建 matchfuzzypos），<BS> 退格，<C-u> 清空；
--            <CR> 选当前，Esc 取消，j/k 仍然可以上下移动。
-- 提示文本（prompt）与当前查询显示在浮窗上边框中间。

local api = vim.api
local fn = vim.fn

local M = {}

M.config = {
	width = 64, -- 浮窗最大宽度（列）
	max_height = 14, -- 最多显示多少项
	border = "rounded",
	pivots = "asdfghjkl", -- 第 10 项起用 M-<pivot> 标签（与 dropbar 的肌肉记忆一致）
}

-- 同一时间只允许一个菜单：重复按键直接取消新请求，不再叠一层
M._busy = false

local ns = api.nvim_create_namespace("lib-menu")

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
	-- 兜底：大小写不敏感的子串匹配（matchfuzzypos 对中文/符号不总是友好）
	local needle = query:lower()
	for i, item in ipairs(items) do
		local text = texts[i]
		local s = text:lower():find(needle, 1, true)
		if s then
			local pos = {}
			for k = s, s + #needle - 1 do
				pos[#pos + 1] = k
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

---上边框中间的标题：提示 + 当前查询（+ 模式标记）
---@param state table
---@return string
function M.title(state)
	local text = state.prompt .. state.query
	if state.mode == "input" then
		text = text .. " ▏"
	end
	return text
end

---计算浮窗位置：优先贴光标下方，放不下就往上收
---@return { row: integer, col: integer }
local function anchor()
	local win = api.nvim_get_current_win()
	local pos = fn.screenpos(win, fn.line("."), 1)
	-- 文本区（越过 statuscolumn / number / sign 列）的起始屏幕列：
	-- 浮窗绝不能压到那里，否则 statuscolumn 上会留下残影
	local info = fn.getwininfo(win)[1]
	local textoff = info and info.textoff or 0
	local left = (fn.win_screenpos(win)[2] or 1) + textoff
	return { row = math.max(1, pos.row), col = math.max(left, pos.col) }
end

---@param state table
local function render(state)
	local view = state.view
	local lines = {}
	local cursor_line = 1
	if #view == 0 then
		lines[1] = state.query == "" and "  (empty)" or "  (no match)"
	end
	for i, entry in ipairs(view) do
		lines[#lines + 1] = " " .. M.line(i, entry.text)
		if i == state.sel then
			cursor_line = i
		end
	end

	state.buf = state.buf or api.nvim_create_buf(false, false)
	api.nvim_set_option_value("modifiable", true, { buf = state.buf })
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = state.buf })
	api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	local height = #lines

	local win_opts = {
		relative = "editor",
		row = state.pos.row,
		col = state.pos.col,
		width = M.config.width,
		height = height,
		style = "minimal",
		border = M.config.border,
		title = M.title(state),
		title_pos = "center",
	}
	if state.win == nil or not api.nvim_win_is_valid(state.win) then
		state.win = api.nvim_open_win(state.buf, false, win_opts)
		api.nvim_set_option_value("winhl", "Normal:Pmenu,FloatBorder:FloatBorder,FloatTitle:Title", { win = state.win })
		api.nvim_set_option_value("wrap", false, { win = state.win })
	else
		api.nvim_win_set_config(state.win, win_opts)
	end

	-- 标签与命中位置的高亮（行首一个空格 + 标签 + 空格）
	for i, entry in ipairs(view) do
		local lnum = i - 1
		local label = M.label(i)
		local text_start = 1 + #label + 1
		if label ~= "" then
			api.nvim_buf_set_extmark(state.buf, ns, lnum, 1, {
				end_col = 1 + #label,
				hl_group = "Identifier",
			})
		end
		for _, pos in ipairs(entry.positions) do
			local col = text_start + pos
			if col < #lines[i] then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, col, {
					end_col = col + 1,
					hl_group = "Special",
					priority = 200,
				})
			end
		end
	end
	-- 选中行用 extmark 铺满整行（不再依赖 'cursorline'：它会让浮窗参与
	-- 下面窗口 statuscolumn 的重绘，留下残影）
	if cursor_line <= #lines and lines[cursor_line] then
		api.nvim_buf_set_extmark(state.buf, ns, cursor_line - 1, 0, {
			end_col = #lines[cursor_line],
			hl_group = "PmenuSel",
			hl_eol = true,
			priority = 50,
		})
	end
	pcall(api.nvim_win_set_cursor, state.win, { cursor_line, 0 })
	-- 阻塞读键前必须显式刷一次：nvim 在等待输入时不会自动 flush 待处理的浮窗重绘，
	-- 少了这一句表现为「按了快捷键什么都没弹出」。
	if vim.go.columns > 0 then
		pcall(vim.cmd, "redraw")
	end
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
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		pcall(api.nvim_buf_delete, state.buf, { force = true })
	end
	state.win, state.buf = nil, nil
	-- 关掉浮窗后强制整屏重绘：浮窗占过的区域（尤其 statuscolumn）不会被自动置脏，
	-- 会留下深色竖纹残影，直到下一次整屏重绘（比如另一个浮窗弹出）才消失。
	if vim.go.columns > 0 then
		pcall(vim.cmd, "redraw!")
		-- 再排一次：nvim 自己那一轮重绘可能在我们之后，会把 statuscolumn 画回旧内容
		vim.schedule(function()
			pcall(vim.cmd, "redraw!")
		end)
	end
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
			if key == "\27" then
				break
			end
			local k = fn.keytrans(key)
			local kl = k:lower() -- 特殊键 keytrans 可能大写（<C-N>）

			if kl == "<esc>" or kl == "<c-c>" or kl == "<c-g>" then
				break
			elseif kl == "<cr>" or kl == "<nl>" then
				local entry = state.view[state.sel]
				if entry then
					state.choice = entry
				end
				break
			elseif kl == "<down>" or kl == "<c-n>" then
				move(1)
			elseif kl == "<up>" or kl == "<c-p>" then
				move(-1)
			elseif kl == "<bs>" then
				if state.query ~= "" then
					state.query = state.query:sub(1, -2)
					refilter()
				end
			elseif kl == "<c-u>" then
				if state.query ~= "" then
					state.query = ""
					refilter()
				end
			elseif kl:match("^<m%-(%a)>$") then
				local pivot = kl:match("^<m%-(%a)>$")
				local idx = M.config.pivots:find(pivot, 1, true)
				if idx and state.view[idx + 9] then
					state.sel = idx + 9
					state.choice = state.view[state.sel]
					break
				end
			elseif kl:match("^%d$") then
				local idx = tonumber(kl)
				if state.view[idx] then
					state.sel = idx
					state.choice = state.view[state.sel]
					break
				end
			elseif kl == "j" or kl == "k" then
				-- 导航模式下 j/k 上下移动；输入模式下 j/k 是查询字符
				if state.mode == "normal" then
					move(kl == "j" and 1 or -1)
				else
					state.query = state.query .. kl
					refilter()
				end
			elseif state.mode == "normal" and (kl == "q") then
				break
			elseif #k == 1 and (k == "i" or k == "f" or k == "/") and state.mode == "normal" then
				state.mode = "input"
			elseif #k == 1 and k:byte() >= 32 and k:byte() < 127 then
				-- 输入模式下才吃掉可打印字符
				if state.mode == "input" then
					state.query = state.query .. k
					refilter()
				end
			end
		end
	end)
	close(state)
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
