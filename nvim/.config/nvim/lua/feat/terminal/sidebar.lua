-- 终端侧栏：列出「所有 tab（工作区）」的终端，点一下切过去。
--
-- 定位：贴在终端面板右侧的一条窄竖栏（不是 neo-tree 那种通高侧栏），
-- 和终端面板同生同灭——`C-;` 收起时一起收，进程都还在。
--
-- 为什么是全局视图：bufferline 管「本工作区有哪些文件」，终端侧栏管
-- 「整个 nvim 有哪些终端」（跨工作区总览），正好互补；切过去时自动跳 tab。
-- 侧栏 buffer 用 nofile + filetype 走 EXCLUDED_FILETYPES，不参与 tab 归属
-- 与会话恢复（tab_workspace 不管它）。
local api, fn = vim.api, vim.fn

local state = require("feat.terminal.state")

local M = {}

local NS = api.nvim_create_namespace("tw_term_sidebar")

local FT = "tw_term_sidebar"

---@type { width: integer }
M.config = { width = 22 }

----------------------------------------------------------------------
-- 行尾关闭按钮
----------------------------------------------------------------------

--- 关闭字形：和 winbar chip 上的那个用同一个（可配）
---@return string
local function close_glyph()
	local ok, icon = pcall(function()
		return M.host.close_icon()
	end)
	if not ok or type(icon) ~= "string" or icon == "" then
		return "☓"
	end
	return icon
end

--- 把「前缀 + 序号 + 名字」裁到 cols 显示宽，再把关闭按钮右对齐到行尾
--- 右边故意留一列：窗口最后一列在分屏里可能被当成分隔线（点上去会变成拖拽分屏）
---@param text string
---@param glyph string
---@param cols integer 名字可用的显示宽度
---@return string line, integer close_byte 关闭按钮的起始字节（0-based）
local function with_close(text, glyph, cols)
	local body = text
	while body ~= "" and fn.strdisplaywidth(body) > cols do
		body = fn.strcharpart(body, 0, fn.strchars(body) - 1)
	end
	local pad = string.rep(" ", math.max(cols - fn.strdisplaywidth(body), 0) + 1)
	return body .. pad .. glyph, #body + #pad
end

--- 全局唯一的侧栏 buffer（内容永远是全量终端，和 tab 无关）
---@type integer|nil
local buf

--- CursorMoved 里再触发 jump 的重入闸
local clicking = false

--- reset_view 的重入闸（winrestview 会再发 WinScrolled）
local fixing = false

--- line(0-based) -> item：{ tab, bufnr } 或 { tab, header = true }
---@type table<integer, table>
local items = {}

--- 侧栏里的鼠标点击入口（定义在后面，这里先占位给 ensure_buf 用）
---@type fun(pos?: table)
local click_action

----------------------------------------------------------------------
-- 数据
----------------------------------------------------------------------

--- 某个 tab 的工作区名（:tcd 的根目录，取末段）
---@param tab integer
---@return string
local function tab_root(tab)
	if not api.nvim_tabpage_is_valid(tab) then
		return "?"
	end
	local nr = api.nvim_tabpage_get_number(tab)
	local ok, cwd = pcall(fn.getcwd, -1, nr)
	if not ok or type(cwd) ~= "string" or cwd == "" then
		return "?"
	end
	local tail = fn.fnamemodify(cwd, ":t")
	return tail ~= "" and tail or cwd
end

--- 终端显示名（去掉目录前缀和序号，序号单独一列）
---@param bufnr integer
---@return string
local function term_label(bufnr)
	local name = api.nvim_buf_get_name(bufnr)
	if name == "" then
		return "Term"
	end
	local base = fn.fnamemodify(name, ":t")
	-- 去掉全局序号后缀（"Term (3)" -> "Term"），序号在左边单独一列
	return (base:gsub("%s*%(?%d+%)?$", ""))
end

----------------------------------------------------------------------
-- 高亮
----------------------------------------------------------------------

local highlights = require("feat.terminal.highlights")

local function define_hl()
	highlights.apply()
end

----------------------------------------------------------------------
-- 渲染
----------------------------------------------------------------------

--- 终端进程是否还活着（死掉的终端行标灰，进程退出但 buffer 还在）
---@param bufnr integer
---@return boolean
local function is_alive(bufnr)
	local ok, chan = pcall(fn.jobpid, vim.b[bufnr].terminal_job_id)
	return ok and chan ~= nil and chan ~= 0
end

--- 侧栏是“给鼠标看的列表”，不是可编辑文档：内容装得下就永远顶在窗口第一行，
--- 也永远不横向滚动。全局 scrolloff/sidescrolloff 会把短 buffer 往中间推（点一下就
--- 滚出屏幕），所以每回交互后都把视图拉回来。
--- 思路参考 filler-begone.nvim（redraw 守护视图，不让 filler 露出来），
--- 但那边是“底对齐 + nvim_win_text_height 算换行/折叠高度 + 二分找 topline”，
--- 侧栏 wrap=false 且要顶对齐，直接 topline=1 就够，用不上那套。
---@param win integer
local function reset_view(win)
	if fixing or not (win and api.nvim_win_is_valid(win)) then
		return
	end
	fixing = true
	pcall(api.nvim_win_call, win, function()
		local view = fn.winsaveview()
		local topline = view.topline
		if api.nvim_buf_line_count(0) <= fn.winheight(0) then
			topline = 1
		end
		if view.leftcol == 0 and topline == view.topline then
			return
		end
		view.leftcol = 0
		view.topline = topline
		fn.winrestview(view)
	end)
	fixing = false
end

--- 重画侧栏（所有 tab 的终端都会出现在里面）
function M.render()
	if not (buf and api.nvim_buf_is_valid(buf)) then
		return
	end

	local cur_tab = api.nvim_get_current_tabpage()
	local glyph = close_glyph()
	-- 名字可用宽度 = 窗口实际宽 - 关闭字形 - 2 列余量
	-- 右边留 2 列：最后一列在分屏里会被当分隔线，且留点余量后点 ✕ 不会把光标顶出可见区
	local swin = M.win(cur_tab)
	local width = (swin and api.nvim_win_is_valid(swin) and api.nvim_win_get_width(swin)) or M.config.width
	local cols = math.max(width - fn.strdisplaywidth(glyph) - 3, 1)
	local lines = {}
	local hl = {}
	local map = {}

	for _, tab in ipairs(state.tabs()) do
		local list = state.list(tab)
		if #list > 0 then
			local active = state.active(tab)
			-- 组头：tab 序号 + 工作区名
			local label = ("%d  %s"):format(api.nvim_tabpage_get_number(tab), tab_root(tab))
			lines[#lines + 1] = vim.fn.strcharpart(label, 0, M.config.width - 1)
			hl[#hl + 1] = "TwTermSbHeader"
			-- items 用 0-based 行号做 key，直接对得上 nvim_win_get_cursor
			map[#lines - 1] = { tab = tab, header = true }

			for _, bufnr in ipairs(list) do
				local is_cur = tab == cur_tab and bufnr == active
				local prefix = is_cur and "▏" or " "
				local label = ("%s%d %s"):format(prefix, vim.b[bufnr].tw_term_index or 0, term_label(bufnr))
				-- 行尾一律给关闭按钮留一列（名字太长就裁名字，不裁按钮）
				local line, close_byte = with_close(label, glyph, cols)
				lines[#lines + 1] = line
				if is_cur then
					hl[#hl + 1] = "TwTermSbActive"
				elseif not is_alive(bufnr) then
					hl[#hl + 1] = "TwTermSbDead"
				else
					hl[#hl + 1] = "TwTermSbItem"
				end
				map[#lines - 1] = { tab = tab, bufnr = bufnr, close_byte = close_byte, close_hl = is_cur }
			end
		end
	end

	if #lines == 0 then
		lines = { "没有终端" }
		hl = { "TwTermSbDead" }
	end
	items = map

	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false

	api.nvim_buf_clear_namespace(buf, NS, 0, -1)
	for i, group in ipairs(hl) do
		api.nvim_buf_set_extmark(buf, NS, i - 1, 0, {
			end_line = i,
			hl_group = group,
			hl_eol = true,
		})
	end

	-- 行尾的关闭按钮单独上色（行底色已经铺过，这里只覆盖那几列）
	for line, item in pairs(map) do
		if item.close_byte then
			api.nvim_buf_set_extmark(buf, NS, line, item.close_byte, {
				end_col = item.close_byte + #glyph,
				hl_group = item.close_hl and "TwTermSbCloseActive" or "TwTermSbClose",
			})
		end
	end

	-- 让光标停在当前 tab 的活动终端上（每个侧栏窗口同步）
	for tab, win in pairs(M.wins()) do
		if api.nvim_win_is_valid(win) then
			for line, item in pairs(items) do
				if item.bufnr and item.tab == tab and item.bufnr == state.active(tab) then
					pcall(api.nvim_win_set_cursor, win, { line + 1, 0 })
					break
				end
			end
			-- 列表变短时光标可能停在越界行上
			local cur = api.nvim_win_get_cursor(win)[1]
			if cur > #lines then
				pcall(api.nvim_win_set_cursor, win, { #lines, 0 })
			end
			-- 不要横向滚动、内容装得下就不要上下滚（scrolloff 会把短列表推走）
			reset_view(win)
		end
	end
end

----------------------------------------------------------------------
-- 窗口
----------------------------------------------------------------------

--- 所有 tab 的侧栏窗口
---@return table<integer, integer>
function M.wins()
	local out = {}
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			if api.nvim_win_is_valid(win) and vim.w[win].tw_term_sidebar and api.nvim_win_get_buf(win) == buf then
				out[tab] = win
			end
		end
	end
	return out
end

--- 该 tab 的侧栏窗口
---@param tab integer
---@return integer|nil
function M.win(tab)
	for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
		if vim.w[win].tw_term_sidebar then
			-- 窗口被 :bwipeout / :b 抢走 buffer 时，别把「假侧栏」当成真的
			if api.nvim_win_get_buf(win) == buf then
				return win
			end
			vim.w[win].tw_term_sidebar = nil
		end
	end
	return nil
end

local function ensure_buf()
	if buf and api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = api.nvim_create_buf(false, false)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = FT
	vim.b[buf].tw_term_sidebar = true
	vim.bo[buf].buflisted = false
	pcall(api.nvim_buf_set_name, buf, "终端")
	-- buffer 被 :bwipeout 之后不要留一个悬空 id
	local b = buf
	api.nvim_create_autocmd("BufWipeout", {
		buffer = b,
		once = true,
		callback = function()
			if buf == b then
				buf = nil
			end
			-- 侧栏 buffer 被 :bwipeout 后，原侧栏窗口会剩下一个「空白分屏」，
			-- 顺手收掉，否则下次 open 会在旁边再切一刀，越积越多
			vim.schedule(function()
				for _, tab in ipairs(api.nvim_list_tabpages()) do
					for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
						if api.nvim_win_is_valid(win) and vim.w[win].tw_term_sidebar then
							vim.w[win].tw_term_sidebar = nil
							if #api.nvim_tabpage_list_wins(tab) > 1 then
								pcall(api.nvim_win_hide, win)
							end
						end
					end
				end
			end)
		end,
	})

	-- 鼠标点一下就切；点在行尾的关闭按钮上就是关该终端（含从别的窗口点过来的第一下）
	clicking = false
	api.nvim_create_autocmd("CursorMoved", {
		group = api.nvim_create_augroup("FeatTermSidebarClick", { clear = true }),
		buffer = b,
		callback = function()
			if clicking or api.nvim_get_current_buf() ~= b then
				return
			end
			local pos = M.mouse_pos()
			if not pos then
				return
			end
			-- 点行尾时光标被顶出行宽、nvim 会把 leftcol 推上去，整栏字往左滑，先收回
			reset_view(api.nvim_get_current_win())
			clicking = true
			local ok, err = pcall(click_action, pos)
			clicking = false
			if not ok then
				vim.schedule(function()
					error(err)
				end)
			end
		end,
	})

	local o = { buffer = buf, silent = true, nowait = true }
	-- 滚轮 / zz / <C-e> 也不算“编辑”：视图一变就拉回（列表比窗口长时仍允许正常滚动）
	api.nvim_create_autocmd("WinScrolled", {
		group = api.nvim_create_augroup("FeatTermSidebarNoScroll", { clear = true }),
		buffer = b,
		callback = function()
			for _, w in pairs(M.wins()) do
				reset_view(w)
			end
		end,
	})
	-- 切换：跳 tab + 打开面板
	vim.keymap.set("n", "<CR>", function()
		M.jump_at_cursor()
	end, o)
	-- 单击由下面的 CursorMoved 处理（跨窗口第一下也能生效），双击补一手
	vim.keymap.set("n", "<2-LeftMouse>", function()
		click_action(M.mouse_pos())
	end, o)
	-- 侧栏不是可编辑文档：单击直接命中行，拖拽既不选区也不滚动
	local mm = { buffer = buf, silent = true, noremap = true }
	vim.keymap.set({ "n", "v", "x" }, "<LeftMouse>", function()
		M.click_action(fn.getmousepos())
	end, mm)
	vim.keymap.set({ "n", "v", "x" }, "<LeftDrag>", "<Ignore>", mm)
	vim.keymap.set({ "n", "v", "x" }, "<LeftRelease>", "<Ignore>", mm)
	vim.keymap.set("n", "x", function()
		local item = M.item_at_cursor()
		if item then
			M.host.kill(item.bufnr)
		end
	end, vim.tbl_extend("force", o, { desc = "结束该终端" }))
	vim.keymap.set("n", "q", function()
		M.host.hide()
	end, vim.tbl_extend("force", o, { desc = "收起终端" }))
	return buf
end

--- 侧栏窗口的窗口选项（open() 与 restore_win() 共用）
---@param win integer
local function apply_win_opts(win)
	api.nvim_set_option_value("number", false, { win = win })
	api.nvim_set_option_value("relativenumber", false, { win = win })
	api.nvim_set_option_value("signcolumn", "no", { win = win })
	api.nvim_set_option_value("foldcolumn", "0", { win = win })
	api.nvim_set_option_value("statuscolumn", "", { win = win })
	api.nvim_set_option_value("spell", false, { win = win })
	api.nvim_set_option_value("list", false, { win = win })
	api.nvim_set_option_value("wrap", false, { win = win })
	api.nvim_set_option_value("cursorline", true, { win = win })
	api.nvim_set_option_value("winfixwidth", true, { win = win })
	-- 全局 scrolloff=8 / sidescrolloff=5 会把短 buffer 推着滚：侧栏一律关死
	api.nvim_set_option_value("scrolloff", 0, { win = win })
	api.nvim_set_option_value("sidescrolloff", 0, { win = win })
	pcall(api.nvim_set_option_value, "scrolloffpad", 0, { win = win })
	-- 顶部沿用面板那条 bar（色块连续），左对齐一个小标题
	api.nvim_set_option_value("winbar", "%#TwTermBar# Terminals %#TwTermBar#%X", { win = win })
	-- 侧栏自己一层底色（比终端面板亮一档）+ 一条可见的分隔线
	api.nvim_set_option_value(
		"winhighlight",
		highlights.sidebar_winhl(win == api.nvim_get_current_win()),
		{ win = win }
	)
end

--- 会话恢复用：把一个已有窗口就地变成侧栏窗口（不新建分屏）
---@param win integer
---@return integer|nil win
function M.restore_win(win)
	if not api.nvim_win_is_valid(win) then
		return
	end
	ensure_buf()
	vim.w[win].tw_term_sidebar = true
	api.nvim_win_set_buf(win, buf)
	apply_win_opts(win)
	api.nvim_win_set_width(win, M.config.width)
	M.render()
	return win
end

--- 在 panel 窗口右侧开侧栏（已有则复用）
---@param panel_win integer
---@param tab integer
---@return integer win
function M.open(panel_win, tab)
	ensure_buf()
	local win = M.win(tab)
	if not win then
		-- 从终端面板窗口纵向切一刀：底部分屏被切成 [终端 | 侧栏]
		api.nvim_set_current_win(panel_win)
		vim.cmd("vsplit")
		win = api.nvim_get_current_win()
		vim.w[win].tw_term_sidebar = true
		api.nvim_win_set_buf(win, buf)
		apply_win_opts(win)
	end
	api.nvim_win_set_width(win, M.config.width)
	api.nvim_set_current_win(panel_win)
	M.render()
	return win
end

--- 收起该 tab 的侧栏（buffer 留着）
---@param tab integer
function M.hide(tab)
	local win = M.win(tab)
	if win and api.nvim_win_is_valid(win) then
		api.nvim_win_hide(win)
	end
end

--- 某一行(0-based)对应的终端条目；条目过期（buffer 已删）就当没有
---@param line0 integer
---@return table|nil
local function item_at_line(line0)
	local item = items[line0]
	if item and item.bufnr and api.nvim_buf_is_valid(item.bufnr) and vim.b[item.bufnr].tw_term then
		return item
	end
	return nil
end

--- 光标那一行的终端（没有则 nil）
---@return table|nil
function M.item_at_cursor()
	return item_at_line(api.nvim_win_get_cursor(0)[1] - 1)
end

--- 鼠标是不是「刚被鼠标点过来」的；是就把鼠标位置返回（含窗口内列）。
--- 用途：nvim 里 buffer-local 的 <LeftMouse> 只在**当前窗口**才命中，从别的
--- 窗口点过来时第一下只切焦点、不触发映射（要再点一下）。所以改成监听
--- CursorMoved：真实点击会把光标挪到点中的那一行，而键盘移动几乎不可能
--- 正好落在上一次点击的同一屏幕格子里。
---@return table|nil pos getmousepos 的结果（含 wincol）
function M.mouse_pos()
	local ok, pos = pcall(fn.getmousepos)
	if not ok or type(pos) ~= "table" then
		return nil
	end
	if (tonumber(pos.line) or 0) <= 0 then
		return nil
	end
	if pos.winid ~= api.nvim_get_current_win() then
		return nil
	end
	local cur = api.nvim_win_get_cursor(0)
	if pos.line ~= cur[1] then
		return nil
	end
	-- 行内列会被夹到行尾，只比屏幕行
	local ok2, sp = pcall(fn.screenpos, api.nvim_get_current_win(), cur[1], 1)
	if not (ok2 and type(sp) == "table" and sp.row == pos.screenrow) then
		return nil
	end
	return pos
end

---@return boolean
function M.cursor_is_mouse()
	return M.mouse_pos() ~= nil
end

--- 关闭按钮在侧栏窗口里起始的屏幕列（1-based）
---@return integer
local function close_col()
	local width = api.nvim_win_get_width(0)
	return math.max(width - fn.strdisplaywidth(close_glyph()) - 2, 1)
end

--- 鼠标点在哪一行、哪一列（优先用鼠标位置，没有鼠标信息就退回光标）
---@param pos table|nil getmousepos 的结果
---@return table|nil item
---@return integer col 0-based 字节列
local function click_target(pos)
	-- 映射里拿到的 getmousepos() 可能是上一次点击的缓存位置：窗口对不上就当作没有
	if pos and pos.winid ~= api.nvim_get_current_win() then
		pos = nil
	end
	if pos and (tonumber(pos.line) or 0) > 0 then
		local item = item_at_line(pos.line - 1)
		if item then
			return item, math.max((tonumber(pos.column) or 1) - 1, 0)
		end
	end
	local cur = api.nvim_win_get_cursor(0)
	return item_at_line(cur[1] - 1), cur[2]
end

--- 侧栏里鼠标点击的总入口：点在 ✕ 上就关终端，点别处就切过去
---@param pos table|nil getmousepos 的结果
function M.click_action(pos)
	local item, col = click_target(pos)
	if not item or not item.bufnr then
		return
	end
	local wincol = tonumber(pos and pos.wincol) or 0
	-- ①点中的字节列已经在 ✕ 上 ②或屏幕列到了 ✕ 起始列（右侧余量、宽度算错时的兜底）
	local on_x = item.close_byte ~= nil and (col >= item.close_byte or (wincol > 0 and wincol >= close_col()))
	if on_x then
		M.host.kill(item.bufnr)
	else
		M.host.open(item.bufnr)
	end
	-- 点完把视图拉回来（scrolloff 可能刚把短列表推过）
	reset_view(api.nvim_get_current_win())
end

click_action = M.click_action

--- 切到光标下的终端。
--- 侧栏只管「换终端」，不换 tab / 不换主编辑区 buffer：点别的工作区的终端时，
--- 把那个终端收编到当前 tab 显示（终端的 cwd 还是它当初的启动目录）。
function M.jump_at_cursor()
	local item = M.item_at_cursor()
	if not item then
		return
	end
	M.host.open(item.bufnr)
end

--- 关掉光标那一行的终端（行尾 ✕ 走这里；键盘 x 直接用 item_at_cursor）
function M.close_at_cursor()
	local item = M.item_at_cursor()
	if not item then
		return
	end
	M.host.kill(item.bufnr)
end

--- 该 buffer 是不是侧栏
---@param bufnr integer
---@return boolean
function M.is_sidebar_buf(bufnr)
	return bufnr == buf
end

--- host 由 feat.terminal 注入（close_icon / open / kill / hide），
--- 这样本文件对 feat.terminal 零回指，加载图保持单向：init → sidebar。
---@param host { close_icon: function, open: function, kill: function, hide: function }
function M.setup(host)
	M.host = host
	define_hl()
	api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("FeatTermSidebarHl", { clear = true }),
		callback = define_hl,
	})
end

return M
