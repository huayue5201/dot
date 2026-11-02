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

--- 全局唯一的侧栏 buffer（内容永远是全量终端，和 tab 无关）
---@type integer|nil
local buf

--- CursorMoved 里再触发 jump 的重入闸
local clicking = false

--- line(0-based) -> item：{ tab, bufnr } 或 { tab, header = true }
---@type table<integer, table>
local items = {}

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

--- 重画侧栏（所有 tab 的终端都会出现在里面）
function M.render()
	if not (buf and api.nvim_buf_is_valid(buf)) then
		return
	end

	local cur_tab = api.nvim_get_current_tabpage()
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
				lines[#lines + 1] = vim.fn.strcharpart(label, 0, M.config.width - 1)
				if is_cur then
					hl[#hl + 1] = "TwTermSbActive"
				elseif not is_alive(bufnr) then
					hl[#hl + 1] = "TwTermSbDead"
				else
					hl[#hl + 1] = "TwTermSbItem"
				end
				map[#lines - 1] = { tab = tab, bufnr = bufnr }
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

	-- 鼠标点一下就切（含从别的窗口点过来的第一下）
	clicking = false
	api.nvim_create_autocmd("CursorMoved", {
		group = api.nvim_create_augroup("FeatTermSidebarClick", { clear = true }),
		buffer = b,
		callback = function()
			if clicking or api.nvim_get_current_buf() ~= b then
				return
			end
			if not M.cursor_is_mouse() then
				return
			end
			clicking = true
			local ok, err = pcall(M.jump_at_cursor)
			clicking = false
			if not ok then
				vim.schedule(function()
					error(err)
				end)
			end
		end,
	})

	local o = { buffer = buf, silent = true, nowait = true }
	-- 切换：跳 tab + 打开面板
	vim.keymap.set("n", "<CR>", function()
		M.jump_at_cursor()
	end, o)
	-- 单击由下面的 CursorMoved 处理（跨窗口第一下也能生效），双击补一手
	vim.keymap.set("n", "<2-LeftMouse>", function()
		M.jump_at_cursor()
	end, o)
	vim.keymap.set("n", "x", function()
		local item = M.item_at_cursor()
		if item then
			require("feat.terminal").kill(item.bufnr)
		end
	end, vim.tbl_extend("force", o, { desc = "结束该终端" }))
	vim.keymap.set("n", "q", function()
		require("feat.terminal").hide()
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
	-- 顶部沿用面板那条 bar（色块连续），左对齐一个小标题
	api.nvim_set_option_value("winbar", "%#TwTermBar# Terminals %#TwTermBar#%X", { win = win })
	-- 侧栏自己一层底色（比终端面板亮一档）+ 一条可见的分隔线
	api.nvim_set_option_value("winhighlight", highlights.sidebar_winhl(win == api.nvim_get_current_win()), { win = win })
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

--- 光标是不是「刚被鼠标点过来」的。
--- 用途：nvim 里 buffer-local 的 <LeftMouse> 只在**当前窗口**才命中，从别的
--- 窗口点过来时第一下只切焦点、不触发映射（要再点一下）。所以改成监听
--- CursorMoved：真实点击会把光标挪到点中的那一行，而键盘移动几乎不可能
--- 正好落在上一次点击的同一屏幕格子里。
---@return boolean
function M.cursor_is_mouse()
	local ok, pos = pcall(fn.getmousepos)
	if not ok or type(pos) ~= "table" then
		return false
	end
	if (tonumber(pos.line) or 0) <= 0 then
		return false
	end
	if pos.winid ~= api.nvim_get_current_win() then
		return false
	end
	local cur = api.nvim_win_get_cursor(0)
	if pos.line ~= cur[1] then
		return false
	end
	-- 行内列会被夹到行尾，只比屏幕行
	local ok2, sp = pcall(fn.screenpos, api.nvim_get_current_win(), cur[1], 1)
	return ok2 and type(sp) == "table" and sp.row == pos.screenrow
end

--- 切到光标下的终端。
--- 侧栏只管「换终端」，不换 tab / 不换主编辑区 buffer：点别的工作区的终端时，
--- 把那个终端收编到当前 tab 显示（终端的 cwd 还是它当初的启动目录）。
function M.jump_at_cursor()
	local item = M.item_at_cursor()
	if not item then
		return
	end
	require("feat.terminal").open(item.bufnr)
end

--- 该 buffer 是不是侧栏
---@param bufnr integer
---@return boolean
function M.is_sidebar_buf(bufnr)
	return bufnr == buf
end

function M.setup()
	define_hl()
	api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("FeatTermSidebarHl", { clear = true }),
		callback = define_hl,
	})
end

return M
