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
-- 键位：1-9 直接选，10 项以后 M-<pivot>；<CR> 选当前；<C-n>/<Down>、<C-p>/<Up> 移动；
--       <BS> 退格、<C-u> 清空查询；Esc / <C-c> 取消（回调 nil）。

local api = vim.api
local fn = vim.fn

local M = {}

M.config = {
	width = 64, -- 浮窗最大宽度（列）
	max_height = 14, -- 最多显示多少项（不含提示行）
	border = "rounded",
	pivots = "asdfghjkl", -- 第 10 项起用 M-<pivot> 标签（与 dropbar 的肌肉记忆一致）
}

-- 同一时间只允许一个菜单：重复按键直接忽略，不再叠一层
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
---@return { item: any, text: string, positions: integer[] }[]
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

---计算浮窗位置：优先贴光标下方，放不下就往上收
---@return { row: integer, col: integer }
local function anchor()
	local win = api.nvim_get_current_win()
	local row = fn.screenpos(win, fn.line("."), 1).row
	local col = fn.screenpos(win, fn.line("."), 1).col
	local avail = math.max(1, vim.go.lines - row - 2)
	return { row = math.max(1, row), col = math.max(1, col - 1), avail = avail }
end

---@param state table
local function render(state)
	local view = state.view
	local lines = { state.prompt .. state.query }
	local cursor_line = 1
	if #view == 0 then
		lines[2] = state.query == "" and "  (empty)" or "  (no match)"
	end
	for i, entry in ipairs(view) do
		lines[#lines + 1] = " " .. M.line(i, entry.text)
		if i == state.sel then
			cursor_line = #lines
		end
	end

	state.buf = state.buf or api.nvim_create_buf(false, false)
	api.nvim_set_option_value("modifiable", true, { buf = state.buf })
	api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	api.nvim_set_option_value("modifiable", false, { buf = state.buf })
	api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)

	local width = M.config.width
	local height = #lines
	local row = state.pos.row
	if row + height + 1 > vim.go.lines then
		row = math.max(1, vim.go.lines - height - 2)
	end

	local win_opts = {
		relative = "editor",
		row = row,
		col = state.pos.col,
		width = width,
		height = height,
		style = "minimal",
		border = M.config.border,
	}
	if state.win == nil or not api.nvim_win_is_valid(state.win) then
		state.win = api.nvim_open_win(state.buf, false, win_opts)
		api.nvim_set_option_value(
			"winhl",
			"Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel",
			{ win = state.win }
		)
		api.nvim_set_option_value("cursorline", true, { win = state.win })
		api.nvim_set_option_value("wrap", false, { win = state.win })
	else
		api.nvim_win_set_config(state.win, win_opts)
	end

	-- 提示行用低调色
	api.nvim_buf_set_extmark(state.buf, ns, 0, 0, { end_row = 0, end_col = #lines[1], hl_group = "Comment" })
	for i, entry in ipairs(view) do
		-- 第 0 行是提示行，第 i 项在 buffer 的 0-based 行 i；光标行（1-based）是 i + 1
		local lnum = i
		local label = M.label(i)
		local text_start = 1 + #label + 1 -- 行首缩进 + 标签 + 空格
		if label ~= "" then
			api.nvim_buf_set_extmark(state.buf, ns, lnum, 1, {
				end_col = 1 + #label,
				hl_group = "Identifier",
			})
		end
		for _, pos in ipairs(entry.positions) do
			local col = text_start + pos
			if col < #lines[lnum + 1] then
				api.nvim_buf_set_extmark(state.buf, ns, lnum, col, {
					end_col = col + 1,
					hl_group = "Special",
					priority = 200,
				})
			end
		end
	end
	api.nvim_win_set_cursor(state.win, { cursor_line, 0 })
end

---@param state table
local function close(state)
	if state.win and api.nvim_win_is_valid(state.win) then
		api.nvim_win_close(state.win, true)
	end
	if state.buf and api.nvim_buf_is_valid(state.buf) then
		pcall(api.nvim_buf_delete, state.buf, { force = true })
	end
	state.win, state.buf = nil, nil
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
		formatted = opts.format_item,
		sel = 1,
		pos = anchor(),
	}
	state.view = M.filter(items, state.query, state.formatted)

	M._busy = true
	local ok, err = pcall(function()
		while true do
			render(state)
			local key = M._read_key()
			if key == nil then
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
			elseif kl == "<down>" or kl == "<c-n>" or kl == "<tab>" then
				if #state.view > 0 then
					state.sel = state.sel % #state.view + 1
				end
			elseif kl == "<up>" or kl == "<c-p>" or kl == "<s-tab>" then
				if #state.view > 0 then
					state.sel = (state.sel - 2) % #state.view + 1
				end
			elseif kl == "<bs>" then
				if state.query ~= "" then
					state.query = state.query:sub(1, -2)
					state.view = M.filter(items, state.query, state.formatted)
					state.sel = 1
				end
			elseif kl == "<c-u>" then
				if state.query ~= "" then
					state.query = ""
					state.view = M.filter(items, state.query, state.formatted)
					state.sel = 1
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
			elseif #k == 1 and k:byte() >= 32 and k:byte() < 127 then
				state.query = state.query .. k
				state.view = M.filter(items, state.query, state.formatted)
				state.sel = 1
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
