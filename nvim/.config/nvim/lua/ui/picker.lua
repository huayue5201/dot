-- lua/ui/picker.lua
--[[
通用 picker（内部共享库，不对外发布）
====================================
视觉照 pirey/fqf.nvim：**底部整宽分屏** 当列表（真 cursorline 选中、上下移动用
真实光标）+ 列表正上方 **1 行无边框 prompt 浮窗**，没有圆角边框、没有空白填充行。
比 fqf 多两点：条目可以是任意 table（比较文本走 matchfuzzy 的 text_cb）、右侧
可选 preview 竖分屏；并且完全不动 quickfix 列表、不抢全局 vim.ui.select。

    require("ui.picker").pick({
      title = "nurl requests",
      items = items,                        -- 任意值数组
      text = function(item) ... end,        -- 显示 + 过滤用的文本（默认 tostring）
      preview = function(item)              -- 可选：返回 string | string[] | nil
        return lines
      end,
      on_choose = function(item) ... end,   -- <CR>
      on_cancel = function() ... end,       -- 可选
    })

按键（与 fqf 一致）：
  prompt 里：<CR> 选中 / <C-n> <Down> 下 / <C-p> <Up> 上 / <Tab> 跳到列表 / <Esc> <C-c> 关
  列表里  ：<CR> 选中 / j k <C-n> <C-p> 上下 / <Tab> 回 prompt / q <Esc> <C-c> 关
]]
local M = {}

local ns = vim.api.nvim_create_namespace("ui.picker")
local match_ns = vim.api.nvim_create_namespace("ui.picker.match")

-- 过滤命中字符的高亮；默认链到 PmenuMatch（跟补全菜单的匹配字符一致）
vim.api.nvim_set_hl(0, "UiPickerMatch", { link = "PmenuMatch", default = true })

local PREFIX = "> "
-- 列表分屏占编辑区高度的比例，以及最低高度
local HEIGHT_RATIO = 0.45
local MIN_ROWS = 10

---@param s string
---@param max integer 允许的最大显示宽度
---@return string
local function truncate(s, max)
	if max <= 0 then
		return ""
	end
	if vim.fn.strdisplaywidth(s) <= max then
		return s
	end
	local out, w = {}, 0
	for _, ch in ipairs(vim.fn.split(s, "\\zs")) do
		local cw = vim.fn.strdisplaywidth(ch)
		if w + cw > max - 1 then
			break
		end
		out[#out + 1] = ch
		w = w + cw
	end
	return table.concat(out) .. "…"
end

---@param v string|string[]|nil
---@return string[]
local function to_lines(v)
	if v == nil then
		return {}
	elseif type(v) == "table" then
		return v
	end
	return vim.split(tostring(v), "\n", { plain = true })
end

---@class ui.picker.ctx
---@field close fun()
---@field set_items fun(items: table[]) 换一批条目（按当前输入重新过滤）
---@field visible fun(): table[] 当前过滤后可见的原始条目

---@class ui.picker.action
---@field key string 键位（与普通映射一样写，如 "<C-d>"）
---@field desc string 提示文案，显示在计数右侧
---@field fn fun(item, ctx: ui.picker.ctx)

---@class ui.picker.opts
---@field title? string
---@field items table[]
---@field text? fun(item): string
---@field preview? fun(item): string|string[]|nil
---@field filetype? string|fun(item): string 预览窗口的 filetype（决定语法高亮）
---@field rows? integer 列表分屏高度（默认取编辑区高度的 45%，最少 10 行）
---@field on_choose fun(item)
---@field actions? ui.picker.action[] 额外的条目操作（列表/预览区里用）
---@field on_cancel? fun()

---@param opts ui.picker.opts
function M.pick(opts)
	local items = opts.items or {}
	local text_of = opts.text or tostring
	local entries = {}
	for i, item in ipairs(items) do
		entries[i] = { item = item, text = text_of(item) or "", id = i }
	end

	local columns = vim.o.columns
	local origin_win = vim.api.nvim_get_current_win()
	local title = opts.title or "pick"

	local filtered = entries
	local sel = 1
	local updating = false
	local pending = false
	local closed = false

	local list_win, list_buf, prompt_win, prompt_buf, preview_win, preview_buf
	local aug

	------------------------------------------------------------------
	-- 开关窗口
	------------------------------------------------------------------

	-- 收摊时把布局恢复原样：关窗、删 buffer、焦点回原窗口
	local function close()
		if closed then
			return
		end
		closed = true
		if aug and aug > 0 then
			pcall(vim.api.nvim_del_augroup_by_id, aug)
		end
		-- 注意：表字面量里有 nil 时 ipairs 会提前停，所以用 or 0 占位
		for _, w in ipairs({ prompt_win or 0, preview_win or 0, list_win or 0 }) do
			if w > 0 and vim.api.nvim_win_is_valid(w) then
				pcall(vim.api.nvim_win_close, w, true)
			end
		end
		for _, b in ipairs({ prompt_buf or 0, preview_buf or 0, list_buf or 0 }) do
			if b > 0 and vim.api.nvim_buf_is_valid(b) then
				pcall(vim.api.nvim_buf_delete, b, { force = true })
			end
		end
		if vim.api.nvim_win_is_valid(origin_win) then
			pcall(vim.api.nvim_set_current_win, origin_win)
		end
	end

	local function choose()
		local entry = filtered[sel]
		close()
		if entry and opts.on_choose then
			-- 先恢复窗口再干活，避免动作里开窗跟这次的分屏打架
			vim.schedule(function()
				opts.on_choose(entry.item)
			end)
		end
	end

	local function cancel()
		close()
		if opts.on_cancel then
			vim.schedule(opts.on_cancel)
		end
	end

	------------------------------------------------------------------
	-- 窗口：列表（底部整宽分屏）+ preview（右侧竖分屏）+ prompt（1 行浮窗）
	------------------------------------------------------------------

	-- 高度开窗时定下，不随过滤变（否则每敲一个字整屏布局都在抖）
	-- 高度不跟条目数走：固定的比例占屏，少于 MIN_ROWS 时用 MIN_ROWS（屏幕太矮就顶到可用高）
	local avail = math.max(1, vim.o.lines - vim.o.cmdheight - 4)
	local rows = opts.rows or math.floor(avail * HEIGHT_RATIO)
	rows = math.max(math.min(MIN_ROWS, avail), math.min(rows, avail))

	local function new_buf(ft)
		local b = vim.api.nvim_create_buf(false, true)
		vim.bo[b].bufhidden = "wipe"
		vim.bo[b].swapfile = false
		vim.bo[b].filetype = ft
		return b
	end

	-- 列表/预览共用的干净外观：无行号、无侧边栏、不换行
	local function clean_window(win, cursorline)
		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].signcolumn = "no"
		vim.wo[win].foldcolumn = "0"
		-- statuscol.nvim 之类会给每个窗口注入 statuscolumn，这里显式清掉
		vim.wo[win].statuscolumn = ""
		vim.wo[win].wrap = false
		vim.wo[win].cursorline = cursorline
		vim.wo[win].cursorlineopt = "line"
	end

	-- 列表：底部整宽分屏
	vim.cmd("botright split")
	list_win = vim.api.nvim_get_current_win()
	list_buf = new_buf("ui_picker_list")
	vim.bo[list_buf].buftype = "nofile"
	vim.api.nvim_win_set_buf(list_win, list_buf)
	clean_window(list_win, true)
	vim.api.nvim_win_set_height(list_win, rows)

	-- 预览：列表右侧竖分屏
	if opts.preview then
		vim.cmd("vertical rightbelow split")
		preview_win = vim.api.nvim_get_current_win()
		preview_buf = new_buf("ui_picker_preview")
		vim.bo[preview_buf].buftype = "nofile"
		vim.bo[preview_buf].modifiable = false
		vim.api.nvim_win_set_buf(preview_win, preview_buf)
		clean_window(preview_win, false)
		vim.api.nvim_win_set_width(preview_win, math.max(20, math.floor(columns * 0.42)))
	end

	-- prompt：贴在列表窗口正上方的一行浮窗（宽度取分好屏之后的列表宽度）
	prompt_buf = new_buf("ui_picker_prompt")
	vim.bo[prompt_buf].buftype = "prompt"
	vim.fn.prompt_setprompt(prompt_buf, PREFIX)
	prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
		relative = "win",
		win = list_win,
		row = -1,
		col = 0,
		width = math.max(20, vim.api.nvim_win_get_width(list_win)),
		height = 1,
		style = "minimal",
		border = "none",
	})

	-- 用户自己 :q / 关掉列表或 prompt 窗口时整组一起收
	aug = vim.api.nvim_create_augroup("ui.picker." .. tostring(list_win), { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = aug,
		callback = function(ev)
			if closed then
				return
			end
			local win = tonumber(ev.match)
			if win == list_win or win == prompt_win then
				vim.schedule(close)
			end
		end,
	})

	------------------------------------------------------------------
	-- 渲染
	------------------------------------------------------------------

	local function write_list(lines)
		updating = true
		vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
		updating = false
	end

	local last_label
	-- actions 提示放在计数后面（宽度不够就不显示，不换行）
	local hint = ""
	for _, a in ipairs(opts.actions or {}) do
		hint = hint .. ("  %s %s"):format(a.key, a.desc)
	end
	local function render_count()
		local n = #filtered
		local label = ("%s %d/%d"):format(title, n == 0 and 0 or sel, n)
		if label == last_label then
			return
		end
		last_label = label
		local chunks = { { label .. " ", "Comment" } }
		if hint ~= "" then
			local w = vim.fn.strdisplaywidth(label) + vim.fn.strdisplaywidth(hint) + 4
			if w <= vim.api.nvim_win_get_width(prompt_win) then
				chunks[2] = { hint, "NonText" }
			end
		end
		vim.api.nvim_buf_clear_namespace(prompt_buf, ns, 0, -1)
		vim.api.nvim_buf_set_extmark(prompt_buf, ns, 0, 0, {
			virt_text = chunks,
			virt_text_pos = "right_align",
		})
	end

	local function render_preview()
		if not (preview_win and vim.api.nvim_win_is_valid(preview_win)) then
			return
		end
		local entry = filtered[sel]
		local plines = {}
		if entry then
			local ok, res = pcall(opts.preview, entry.item)
			if ok then
				local pw = vim.api.nvim_win_get_width(preview_win) - 1
				for _, l in ipairs(to_lines(res)) do
					plines[#plines + 1] = truncate(l, pw)
				end
			end
		end
		vim.bo[preview_buf].modifiable = true
		vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, plines)
		vim.bo[preview_buf].modifiable = false

		-- 预览走真实 filetype，于是拿到语法/treesitter 高亮（http 报文、ls 代码片段等）
		local ft = opts.filetype
		if type(ft) == "function" then
			if entry then
				local ok, res = pcall(ft, entry.item)
				ft = ok and res or nil
			else
				ft = nil
			end
		end
		local want_ft = type(ft) == "string" and ft or ""
		if vim.bo[preview_buf].filetype ~= want_ft then
			pcall(function()
				vim.api.nvim_buf_call(preview_buf, function()
					vim.bo.filetype = want_ft
				end)
			end)
			-- ftplugin 可能改窗口选项，恢复成我们要的样子
			if vim.api.nvim_win_is_valid(preview_win) then
				vim.wo[preview_win].wrap = false
				vim.wo[preview_win].number = false
				vim.wo[preview_win].signcolumn = "no"
				vim.wo[preview_win].statuscolumn = ""
			end
		end
	end

	---重画列表 + prompt 右侧的 title/count
	---@param marks? integer[][] 每个条目的命中字符字节区间 {start, end}（在 text 内的位置）
	local function render(marks)
		local n = #filtered
		sel = n == 0 and 1 or math.max(1, math.min(sel, n))

		local lines = {}
		if n == 0 then
			lines[1] = "  (无匹配)"
		else
			local text_w = vim.api.nvim_win_get_width(list_win) - 2
			for i, e in ipairs(filtered) do
				lines[i] = "  " .. truncate(e.text, text_w)
			end
		end
		write_list(lines)

		-- 命中字符高亮（位置是相对 text 的字节偏移，列表行前面多了 2 个空格）
		vim.api.nvim_buf_clear_namespace(list_buf, match_ns, 0, -1)
		if marks and n > 0 then
			for row = 1, math.min(#marks, #lines) do
				local line = lines[row]
				for _, p in ipairs(marks[row] or {}) do
					local col, end_col = p[1] + 2, p[2] + 2
					if end_col <= #line then
						pcall(vim.api.nvim_buf_set_extmark, list_buf, match_ns, row - 1, col, {
							end_col = end_col,
							hl_group = "UiPickerMatch",
						})
					end
				end
			end
		end

		if n > 0 then
			pcall(vim.api.nvim_win_set_cursor, list_win, { sel, 0 })
		end
		render_count()
		render_preview()
	end

	local function set_sel(new)
		if #filtered == 0 then
			return
		end
		sel = ((new - 1) % #filtered) + 1
		pcall(vim.api.nvim_win_set_cursor, list_win, { sel, 0 })
		render_count()
		render_preview()
	end

	local function current_query()
		local first = vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or ""
		return first:sub(#PREFIX + 1)
	end

	local function filter()
		local q = current_query()
		local marks
		if q == "" then
			filtered = entries
		else
			-- 两边都转小写：matchfuzzy 是 smartcase，不这样处理时输大写（如 API）
			-- 会变成大小写敏感，一条都匹配不到。ASCII 小写不改变字节长度。
			local lower = string.lower
			local out = vim.fn.matchfuzzypos(entries, lower(q), {
				text_cb = function(e)
					return lower(e.text)
				end,
			})
			local matched, positions, scores = out[1] or {}, out[2] or {}, out[3] or {}

			-- 按匹配度降序（同分保持原顺序）
			local order = {}
			for i = 1, #matched do
				order[i] = i
			end
			table.sort(order, function(a, b)
				if scores[a] ~= scores[b] then
					return scores[a] > scores[b]
				end
				return a < b
			end)

			filtered, marks = {}, {}
			for k, idx in ipairs(order) do
				-- 用 id 把 matchfuzzypos 的副本换回原条目（调用方给的同一张表）
				local e = entries[matched[idx].id or 0]
				if e then
					filtered[k] = e
					-- matchfuzzypos 给的是「字符位置」（不是字节），换成字节区间；
					-- 结束位置用 p+1 的 byteidx，才能包住整个多字节字符（中文一个字 3 字节）
					local cols = {}
					for _, p in ipairs(positions[idx] or {}) do
						local s = vim.fn.byteidx(e.text, p)
						local en = vim.fn.byteidx(e.text, p + 1)
						if s >= 0 and en > s then
							cols[#cols + 1] = { s, en }
						end
					end
					marks[k] = cols
				end
			end
			end
		sel = 1
		render(marks)
	end

	---换一批条目（actions 改完数据后回调），会按当前输入重新过滤
	---@param new_items table[]
	local function set_items(new_items)
		items = new_items
		entries = {}
		for i, item in ipairs(new_items) do
			entries[i] = { item = item, text = text_of(item) or "", id = i }
		end
		sel = 1
		last_label = nil -- 强制重画计数
		filter()
	end

	------------------------------------------------------------------
	-- 按键
	------------------------------------------------------------------

	local function map(mode, lhs, fn, buf)
		vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true, silent = true })
	end

	-- actions 拿到的小工具
	local ctx = {
		close = close,
		set_items = set_items,
		visible = function()
			local t = {}
			for i, e in ipairs(filtered) do
				t[i] = e.item
			end
			return t
		end,
	}
	for _, a in ipairs(opts.actions or {}) do
		local fn = function()
			-- 以真实光标为准（选中态靠 CursorMoved 同步，可能还没跑到）
			local l = vim.api.nvim_win_get_cursor(list_win)[1]
			if l >= 1 and l <= #filtered then
				sel = l
			end
			local e = filtered[sel]
			if not e then
				return
			end
			local ok, err = pcall(a.fn, e.item, ctx)
			if not ok then
				vim.notify(("action %s 失败: %s"):format(a.key, err), vim.log.levels.ERROR)
			end
		end
		map("i", a.key, fn, prompt_buf)
		map("n", a.key, fn, list_buf)
	end

	vim.fn.prompt_setcallback(prompt_buf, choose)
	vim.fn.prompt_setinterrupt(prompt_buf, cancel)

	for _, lhs in ipairs({ "<C-n>", "<Down>", "<C-j>" }) do
		map("i", lhs, function()
			set_sel(sel + 1)
		end, prompt_buf)
	end
	for _, lhs in ipairs({ "<C-p>", "<Up>", "<C-k>" }) do
		map("i", lhs, function()
			set_sel(sel - 1)
		end, prompt_buf)
	end
	map("i", "<Tab>", function()
		vim.api.nvim_set_current_win(list_win)
	end, prompt_buf)
	for _, lhs in ipairs({ "<Esc>", "<C-c>" }) do
		map("i", lhs, cancel, prompt_buf)
	end

	for _, lhs in ipairs({ "<C-n>", "<Down>", "j" }) do
		map("n", lhs, function()
			set_sel(sel + 1)
		end, list_buf)
	end
	for _, lhs in ipairs({ "<C-p>", "<Up>", "k" }) do
		map("n", lhs, function()
			set_sel(sel - 1)
		end, list_buf)
	end
	map("n", "<CR>", function()
		-- 以真实光标为准（选中态是靠 CursorMoved 同步的，可能还没跑到）
		local l = vim.api.nvim_win_get_cursor(list_win)[1]
		if l >= 1 and l <= #filtered then
			sel = l
		end
		choose()
	end, list_buf)
	map("n", "<Tab>", function()
		vim.api.nvim_set_current_win(prompt_win)
		vim.cmd("startinsert!")
	end, list_buf)
	for _, lhs in ipairs({ "<Esc>", "<C-c>", "q" }) do
		map("n", lhs, cancel, list_buf)
	end

	-- 在列表里用真实光标移动时同步选中态和 preview
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = aug,
		buffer = list_buf,
		callback = function()
			if closed or updating then
				return
			end
			local l = vim.api.nvim_win_get_cursor(list_win)[1]
			if l >= 1 and l <= #filtered and l ~= sel then
				sel = l
				render_count()
				render_preview()
			end
		end,
	})

	-- 输入 → 过滤（on_lines 里处在 textlock，改 buffer 要调度出去）
	vim.api.nvim_buf_attach(prompt_buf, false, {
		on_lines = function()
			if updating or closed or pending then
				return
			end
			pending = true
			vim.schedule(function()
				pending = false
				if closed or not vim.api.nvim_buf_is_valid(prompt_buf) then
					return
				end
				filter()
			end)
		end,
	})

	render()
	vim.api.nvim_set_current_win(prompt_win)
	vim.api.nvim_win_set_cursor(prompt_win, { 1, #PREFIX })
	vim.cmd("startinsert!")
end

return M
