-- 每 tab（= 每 workspace）独立终端：底部 panel + winbar 内标签，语义对齐专业 IDE。
--
-- 设计（与 lua/feat/tab_workspace 一致）：
--   * 作用域 = tab：一个 tab 一组终端，切 tab 互不可见；关 tab 时连带结束进程。
--   * 身份键 = tab 句柄（不是序号，:tabmove 不影响），终端 buffer 登记在 state.lua。
--   * hide ≠ destroy：C-; 只是把 panel 窗口 hide 掉，进程和滚动历史都留着。
--   * cwd = 当前 buffer 所属的那个根（多根工作区里可能是辅助根；没有文件时回落到 tab 根目录）。
--     root 变了不会劫持老终端，按 C-t / <leader>TN 新开一个。
--   * 终端 buffer 的 buftype 是 terminal：不进 bufferline（见 feat/tab_workspace/listed.lua），
--     也不该进会话恢复（进程没法存盘）。
local api, fn = vim.api, vim.fn

local state = require("feat.terminal.state")
local sidebar = require("feat.terminal.sidebar")
local highlights = require("feat.terminal.highlights")

local M = {}

local FT = "tw_terminal"

---@class FeatTerminalConfig
---@field position "bot"|"top"
---@field size integer
---@field startinsert boolean
---@field show_tabs boolean
---@field prefix string
---@field new_tab_icon string
---@field sidebar boolean 面板右侧是否带「全局终端侧栏」
---@field bar_hl string winbar「轨道」底色（chip 之间露出来的那层）
---@field tab_icon string 每个终端 chip 前的图标
---@field close_icon string chip 右侧的关闭按钮
---@field bufname_format fun(prefix: string, index: integer): string

---@type FeatTerminalConfig
local opts = {
	position = "bot",
	size = 18,
	startinsert = true,
	show_tabs = true,
	prefix = "Term",
	new_tab_icon = "+",
	sidebar = true,
	-- 色素全在 highlights.lua 里从当前配色推导（换主题自动跟随）
	bar_hl = "TwTermBar",
	tab_icon = "", -- nf-cod-terminal
	close_icon = "☓", -- nf-md-close
	--- 缓冲名格式，与 betterTerm 的 "Term (1)" 一致
	bufname_format = function(prefix, index)
		return ("%s (%d)"):format(prefix, index)
	end,
}

-- winbar 里 %@v:lua.xxx@ 只能引用全局函数路径，所以点击回调挂在这里。
-- key 用 "t<bufnr>"（bufnr 全局唯一），按需注册、失效就清掉。
-- 注意：不能在每次 winbar_text() 里整体重置——refresh_winbars() 会遍历所有 tab 的
-- 面板窗口，重置后只剩最后一个 tab 的回调表，别的 tab 点 winbar 就找不到函数。
_G.__tw_term_click = _G.__tw_term_click or {}
_G.__tw_term_close = _G.__tw_term_close or {}
_G.__tw_term_select = function()
	M.select()
end
_G.__tw_term_new = function()
	M.new()
end

----------------------------------------------------------------------
-- 高亮 / winbar
----------------------------------------------------------------------

-- winbar 的色块由 highlights.lua 提供（从当前配色推导），这里只是把「色块 + 点击区」
-- 拼成一条 bar：每格 `%#<hl>#%@@...@  <bufname>  %X`，末尾接 `+` 按钮，剩余宽度用 bar_hl 填满。
local function define_hl()
	highlights.apply()
	highlights.update_windows()
end

local function buf_label(bufnr)
	local name = api.nvim_buf_get_name(bufnr)
	if name == "" then
		return opts.prefix
	end
	return fn.fnamemodify(name, ":t")
end

--- 终端 buffer 的规范名：Term (1) / build (4)
---@param index integer
---@param name string|nil 自定义名，默认用 opts.prefix
---@return string
local function term_name(index, name)
	return opts.bufname_format(name or opts.prefix, index)
end

--- winbar 的芯片渲染：视觉上模仿 bufferline
---   轨道(TwTermBar) 上浮着每个终端一块 chip：` <icon> <名字> <×> `，
---   选中的 chip 亮一档 + 底部 accent 下划线；行尾一个自带底色的 `+` 按钮。
--- 点击区用 `%@@v:lua.<global>@...%X`：名字/图标区切终端，`×` 关终端，`+` 新建。
local function chip(bufnr, active)
	local key = "t" .. bufnr
	local icon = active and "TwTermTabIconActive" or "TwTermTabIcon"
	local name = active and "TwTermTabActive" or "TwTermTab"
	local close = active and "TwTermTabCloseActive" or "TwTermTabClose"
	local click = "%%@v:lua._G.__tw_term_click.%s@"
	return table.concat({
		("%%#%s#" .. click .. " %s %%X"):format(icon, key, opts.tab_icon),
		("%%#%s#" .. click .. " %s %%X"):format(name, key, buf_label(bufnr)),
		("%%#%s#%%@v:lua._G.__tw_term_close.%s@%s%%X"):format(close, key, opts.close_icon),
		-- 右侧留白也画成 chip 底色，否则关闭按钮会顶在边缘上
		("%%#%s#" .. click .. " %%X"):format(name, key),
	})
end

--- chip 的纯文本（算宽度用，不带 %#hl# 标记）
---@param bufnr integer
---@return string
local function chip_plain(bufnr)
	return (" %s %s %s "):format(opts.tab_icon, buf_label(bufnr), opts.close_icon)
end

--- 窗口窄的时候只画放得下的 chip，剩下的折成 `…N`（可点，弹出选择器），
--- 而且**当前终端一定在屏上**：放不下就把最后一个 chip 换成当前终端。
---@param tab integer
---@param active integer|nil
---@param win integer|nil
---@return string
local function winbar_text(tab, active, win)
	-- 顺手清掉已失效 buffer 的回调（每次重画都会走一遍，量级很小）
	for _, tbl in ipairs({ _G.__tw_term_click, _G.__tw_term_close }) do
		for key in pairs(tbl) do
			local bufnr = tonumber(key:sub(2))
			if not bufnr or not api.nvim_buf_is_valid(bufnr) then
				tbl[key] = nil
			end
		end
	end

	local list = state.list(tab)
	local width = win and api.nvim_win_is_valid(win) and api.nvim_win_get_width(win) or 0
	-- 预算 = 窗口宽 - 左右留白 - `+` 按钮（3 格）
	local budget = width > 0 and (width - 5) or nil

	local active_idx
	for i, bufnr in ipairs(list) do
		if bufnr == active then
			active_idx = i
		end
	end
	-- 先给「当前终端」留位置，保证它不会被折掉
	local reserve = active_idx and (fn.strdisplaywidth(chip_plain(active)) + 1) or 0

	local items = {}
	local used = 1
	for idx, bufnr in ipairs(list) do
		local need = fn.strdisplaywidth(chip_plain(bufnr)) + 1
		if bufnr == active then
			reserve = 0
			items[#items + 1] = { bufnr = bufnr }
			used = used + need
		elseif budget and used + need + reserve > budget and #items > 0 then
			local hidden = 0
			for j = idx, #list do
				if list[j] ~= active then
					hidden = hidden + 1
				end
			end
			if hidden > 0 then
				items[#items + 1] = { marker = hidden }
			end
			if active_idx and active_idx >= idx then
				items[#items + 1] = { bufnr = active }
			end
			break
		else
			items[#items + 1] = { bufnr = bufnr }
			used = used + need
		end
	end

	local parts = { ("%%#%s# %%X"):format(opts.bar_hl) }
	for _, item in ipairs(items) do
		if item.marker then
			parts[#parts + 1] = ("%%#%s#%%@v:lua._G.__tw_term_select@ …%d %%X"):format(opts.bar_hl, item.marker)
		else
			local bufnr = item.bufnr
			local key = "t" .. bufnr
			if not _G.__tw_term_click[key] then
				_G.__tw_term_click[key] = function()
					M.open(bufnr)
				end
			end
			if not _G.__tw_term_close[key] then
				_G.__tw_term_close[key] = function()
					M.kill(bufnr)
				end
			end
			parts[#parts + 1] = chip(bufnr, bufnr == active)
			-- chip 之间留一格轨道色，看起来是一块块独立的按钮
			parts[#parts + 1] = ("%%#%s# %%X"):format(opts.bar_hl)
		end
	end
	parts[#parts + 1] = ("%%#%s#%%@v:lua._G.__tw_term_new@ %s %%X"):format("TwTermNew", opts.new_tab_icon)
	parts[#parts + 1] = ("%%#%s#%%X"):format(opts.bar_hl)
	return table.concat(parts)
end

--- 当前 tab 里显示本 tab 终端的窗口（面板窗口）
---@param tab integer
---@return integer[]
local function panel_wins(tab)
	local out = {}
	if not api.nvim_tabpage_is_valid(tab) then
		return out
	end
	for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
		local buf = api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "terminal" and state.tab_of(buf) == tab then
			out[#out + 1] = win
		end
	end
	return out
end

--- 重画所有终端 panel 的 winbar（关掉 show_tabs 时清空）
local function refresh_winbars()
	if not opts.show_tabs then
		for _, tab in ipairs(api.nvim_list_tabpages()) do
			for _, win in ipairs(panel_wins(tab)) do
				if api.nvim_win_is_valid(win) then
					api.nvim_set_option_value("winbar", "", { win = win })
				end
			end
		end
		return
	end
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		for _, win in ipairs(panel_wins(tab)) do
			if api.nvim_win_is_valid(win) then
				local buf = api.nvim_win_get_buf(win)
				api.nvim_set_option_value("winbar", winbar_text(tab, buf, win), { win = win })
			end
		end
	end
end

--- 重画 winbar + 侧栏（侧栏没开过也是 no-op）
local function redraw()
	refresh_winbars()
	sidebar.render()
	-- 面板/侧栏的 Normal 是靠 winhighlight 映射的，焦点变了要跟着换亮/暗两套
	highlights.update_windows()
end

----------------------------------------------------------------------
-- panel 窗口
----------------------------------------------------------------------

local function attach(win, bufnr, tab)
	-- 不用 winfixbuf：它会挡住 :terminal / nvim_win_set_buf（0.13 里 set_buf 会被
	-- 静默拒掉、buffer 反而跑到别的窗口去），而 panel 窗口是靠 panel_wins() 扫描找的，
	-- 不需要靠这个选项锁死。
	vim.w[win].tw_term_panel = true
	api.nvim_win_set_buf(win, bufnr)
	-- 终端面板自己一套背景（比编辑器暗一档），焦点不同用亮/暗两个变体
	api.nvim_set_option_value("winhighlight", highlights.panel_winhl(win == api.nvim_get_current_win()), { win = win })
	api.nvim_set_option_value("number", false, { win = win })
	api.nvim_set_option_value("relativenumber", false, { win = win })
	api.nvim_set_option_value("signcolumn", "no", { win = win })
	-- 终端窗口不要 statuscolumn（fold/git 列在终端里没意义还占宽）
	api.nvim_set_option_value("statuscolumn", "", { win = win })
	api.nvim_set_option_value("list", false, { win = win })
	api.nvim_set_option_value("wrap", false, { win = win })
	api.nvim_set_option_value("cursorline", false, { win = win })
	api.nvim_set_option_value("spell", false, { win = win })
	if opts.show_tabs then
		api.nvim_set_option_value("winbar", winbar_text(tab, bufnr, win), { win = win })
	end
end

--- 开/显示 panel 窗口
---@param bufnr integer
---@param tab integer
---@return integer win
local function open_panel(bufnr, tab)
	local win = panel_wins(tab)[1]
	if win then
		attach(win, bufnr, tab)
		api.nvim_set_current_win(win)
		if opts.sidebar then
			sidebar.open(win, tab)
		end
		return win
	end
	-- 从当前窗口切一条出来，再换成终端 buffer
	-- 当前窗口是侧栏时（比如点侧栏的 ✕ 关终端）不能拿它当基准切，否则侧栏被挤到上面
	local cur_win = api.nvim_get_current_win()
	if sidebar.is_sidebar_buf(api.nvim_win_get_buf(cur_win)) then
		for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
			if api.nvim_win_is_valid(w) and not sidebar.is_sidebar_buf(api.nvim_win_get_buf(w)) then
				api.nvim_set_current_win(w)
				break
			end
		end
	end
	vim.cmd((opts.position == "top" and "topleft " or "botright ") .. "split")
	win = api.nvim_get_current_win()
	api.nvim_win_set_height(win, opts.size)
	attach(win, bufnr, tab)
	if opts.sidebar then
		sidebar.open(win, tab)
	end
	return win
end

--- hide 掉当前 tab 的 panel（进程保留）
---@param tab integer
---@return boolean 是否真的藏了东西
local function hide_panel(tab)
	sidebar.hide(tab)
	local wins = panel_wins(tab)
	if #wins == 0 then
		return false
	end
	for _, win in ipairs(wins) do
		if api.nvim_win_is_valid(win) then
			if #api.nvim_tabpage_list_wins(tab) > 1 then
				api.nvim_win_hide(win)
			else
				-- 最后一个窗口不能 hide（E444）：换成空 buffer，tab 留着
				api.nvim_win_call(win, function()
					vim.cmd("enew")
				end)
			end
		end
	end
	return true
end

----------------------------------------------------------------------
-- 终端 buffer
----------------------------------------------------------------------

--- 终端里此刻是否有前台程序占着 tty（fzf / less / htop / 交互式 CLI …）。
--- 判据：该 tty 的前台进程组 `tpgid` ≠ shell 自己的进程组 `pgid`。
--- 不用「查子进程」：zsh -i 里 `ff` 是 zsh → bash → fzf 三层，按层数判断会漏；
--- 而 tpgid 与层数无关，shell 里挂着后台任务时也不会误判。
---@param bufnr integer
---@return boolean
function M.has_foreground_program(bufnr)
	local pid = vim.b[bufnr].terminal_job_pid
	if not pid then
		return false
	end
	local out = fn.system({ "ps", "-o", "tpgid=", "-o", "pgid=", "-p", tostring(pid) })
	if vim.v.shell_error ~= 0 then
		return false
	end
	local tpgid, pgid = out:match("^%s*(%d+)%s+(%d+)%s*$")
	return tpgid ~= nil and pgid ~= nil and tpgid ~= pgid
end

local function set_term_keymaps(bufnr)
	local o = { buffer = bufnr, silent = true, nowait = true }
	-- Esc 在这里是二义的：终端里跑着 ff(fzf) / less / htop 时，Esc 属于那个程序
	-- （fzf 用它清空查询再按一次取消）；只有停在 shell 提示符上，Esc 才该是
	-- 「离开终端模式」。以前这里硬映射成 <C-\\><C-n>，于是任何 TUI 都收不到 Esc。
	vim.keymap.set("t", "<Esc>", function()
		if M.has_foreground_program(bufnr) then
			-- 映射把按键拦下了，所以要显式写进 pty
			api.nvim_chan_send(vim.b[bufnr].terminal_job_id, "\27")
		else
			api.nvim_feedkeys(api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
		end
	end, o)
	-- 保底出口：有些全屏 TUI（htop、gdb …）不吃 Esc，Esc 会被原样送进程序，
	-- 想回普通模式就用这个组合，TUI 基本不会抢它。
	vim.keymap.set("t", "<C-Esc>", [[<C-\><C-n>]], o)
	for _, k in ipairs({ "h", "j", "k", "l" }) do
		vim.keymap.set("t", "<C-" .. k .. ">", "<Cmd>wincmd " .. k .. "<CR>", o)
	end
	vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], o)
	vim.keymap.set("t", "<C-t>", function()
		M.new()
	end, o)
	vim.keymap.set("t", "<C-;>", function()
		M.toggle()
	end, o)
	vim.keymap.set({ "n", "t" }, "<C-PageUp>", function()
		M.cycle(1)
	end, o)
	vim.keymap.set({ "n", "t" }, "<C-PageDown>", function()
		M.cycle(-1)
	end, o)
	for i = 1, 9 do
		vim.keymap.set("t", "<A-" .. i .. ">", function()
			M.open(i)
		end, o)
	end
end

--- 在当前 tab 里新建终端（不显示）
---@param tab integer
---@param cwd string|nil 工作目录（缺省用当前窗口的，:tcd 之后 getcwd() 就是本 tab 的根目录）
---@return integer bufnr
local function create(tab, cwd)
	cwd = cwd or fn.getcwd()
	local bufnr = api.nvim_create_buf(true, false)
	local index = state.next_index()
	-- 先打标记再 termopen：TermOpen 的 autocmd 会据此判断是不是本模块创建的
	vim.b[bufnr].tw_term = true
	vim.b[bufnr].tw_term_index = index
	vim.b[bufnr].tw_term_cwd = cwd
	api.nvim_buf_call(bufnr, function()
		fn.termopen(vim.o.shell, { cwd = cwd })
	end)
	pcall(api.nvim_buf_set_name, bufnr, term_name(index))
	vim.bo[bufnr].filetype = FT
	-- 终端不进 bufferline / :ls / :bnext（betterTerm 同样做法），有自己的侧栏
	vim.bo[bufnr].buflisted = false
	state.add(tab, bufnr)
	redraw()
	return bufnr
end

--- 新终端的工作目录：当前 buffer 所属的那个根（多根工作区里可能是辅助根），
--- 兜底用本 tab 的根目录（:tcd 之后 getcwd() 就是主根）。
---@param tab integer
---@return string
local function terminal_cwd(tab)
	local ok, roots = pcall(require, "feat.tab_workspace.roots")
	if ok then
		local name = api.nvim_buf_get_name(api.nvim_get_current_buf())
		if name ~= "" then
			local dir = roots.find_root(tab, name)
			if dir then
				return dir
			end
		end
	end
	local nr = api.nvim_tabpage_get_number(tab)
	local ok_cwd, cwd = pcall(fn.getcwd, -1, nr)
	if ok_cwd and type(cwd) == "string" and cwd ~= "" then
		return cwd
	end
	return fn.getcwd()
end

--- 新终端并显示
---@param cwd? string 工作目录；缺省 = 当前文件所属的根（主根或辅助根）
---@return integer bufnr
function M.new(cwd)
	local tab = api.nvim_get_current_tabpage()
	local bufnr = create(tab, cwd or terminal_cwd(tab))
	open_panel(bufnr, tab)
	if opts.startinsert and fn.mode() ~= "t" then
		vim.cmd.startinsert()
	end
	return bufnr
end

--- 从 neo-tree 节点开终端：目录节点 = 该目录，文件节点 = 文件所在目录。
--- 多根工作区里从辅助根一路按 <C-t>，终端就落在辅助根下的那个目录。
---@param node table neo-tree 节点（需要 type 与 get_id）
---@return integer|nil bufnr
function M.new_for_node(node)
	if type(node) ~= "table" or type(node.get_id) ~= "function" then
		return nil
	end
	local ok, id = pcall(node.get_id, node)
	if not ok or type(id) ~= "string" or id == "" then
		return nil
	end
	-- 合成节点（workspace://roots 之类）不是真实路径
	if id:match("^%a[%w+.-]*://") then
		return nil
	end
	local dir = node.type == "directory" and id or fn.fnamemodify(id, ":h")
	if dir == "" or fn.isdirectory(dir) == 0 then
		return nil
	end
	return M.new(dir)
end

--- 会话恢复用：把一个已有窗口就地变成终端窗口（不新建分屏）。
--- 终端进程没法存盘，所以这里起一个新 shell，位置/尺寸由 resession 还原。
---@param win integer
---@param as_panel boolean|nil 是否按 panel 窗口处理（winbar、无行号、statuscolumn 等）
---@return integer|nil win
function M.restore_win(win, as_panel)
	if not api.nvim_win_is_valid(win) then
		return
	end
	local tab = api.nvim_win_get_tabpage(win)
	local cwd = fn.getcwd(-1, api.nvim_tabpage_get_number(tab))
	local bufnr = create(tab, cwd)
	-- TermOpen 的 autocmd 把终端登记到「当前 tab」，这里以窗口所属 tab 为准
	state.adopt(tab, bufnr)
	state.active(tab, bufnr)
	if as_panel then
		attach(win, bufnr, tab)
	else
		api.nvim_win_set_buf(win, bufnr)
	end
	redraw()
	return win
end

--- 显示某个终端（bufnr 或本 tab 的第 N 个）
---@param target integer|string|nil
---@return integer|nil bufnr
function M.open(target)
	local tab = api.nvim_get_current_tabpage()
	local bufnr
	if type(target) == "number" and api.nvim_buf_is_valid(target) and vim.b[target].tw_term then
		bufnr = target
	else
		local index = tonumber(target) or 1
		bufnr = state.list(tab)[index]
		if not bufnr then
			bufnr = create(tab)
		end
	end
	-- 终端 buffer 被 :b 搬到别的 tab 时收编到当前 tab
	local owner = state.tab_of(bufnr)
	if owner and owner ~= tab then
		state.adopt(tab, bufnr)
	end
	state.active(tab, bufnr)
	open_panel(bufnr, tab)
	if opts.startinsert and fn.mode() ~= "t" then
		vim.cmd.startinsert()
	end
	return bufnr
end

--- C-;：显示 / 隐藏当前 tab 的终端面板
function M.toggle()
	local tab = api.nvim_get_current_tabpage()
	if hide_panel(tab) then
		return
	end
	local bufnr = state.active(tab)
	if not bufnr then
		bufnr = create(tab)
	end
	state.active(tab, bufnr)
	open_panel(bufnr, tab)
	if opts.startinsert and fn.mode() ~= "t" then
		vim.cmd.startinsert()
	end
end

--- 显式隐藏（不结束进程）
function M.hide()
	hide_panel(api.nvim_get_current_tabpage())
end

--- 在本 tab 的多个终端间循环
---@param shift integer|nil
function M.cycle(shift)
	local tab = api.nvim_get_current_tabpage()
	local list = state.list(tab)
	if #list == 0 then
		return M.new()
	end
	local cur = api.nvim_get_current_buf()
	local at = 1
	for i, b in ipairs(list) do
		if b == cur then
			at = i
		end
	end
	local next_at = ((at - 1 + (shift or 1)) % #list) + 1
	return M.open(list[next_at])
end

--- 重命名当前终端（名字后面保留全局序号，避免同名 buffer）
---@param new_name string|nil
function M.rename(new_name)
	local bufnr = api.nvim_get_current_buf()
	if not vim.b[bufnr].tw_term then
		vim.notify("current buffer is not a terminal", vim.log.levels.WARN)
		return
	end
	local apply = function(name)
		if not name or name == "" then
			return
		end
		local suffix = vim.b[bufnr].tw_term_index or 0
		-- 重名会直接报错，先探一下而不是让用户看到 E95
		local ok = pcall(api.nvim_buf_set_name, bufnr, term_name(suffix, name))
		if not ok then
			vim.notify("a buffer with that name already exists: " .. name, vim.log.levels.WARN)
			return
		end
		redraw()
	end
	if new_name then
		apply(new_name)
	else
		vim.ui.input({ prompt = "Terminal name: ", default = buf_label(bufnr) }, apply)
	end
end

--- 选择并切到本 tab 的某个终端（单飞由 lib/menu 保证：菜单开着时再按不会叠一层）
function M.select()
	local tab = api.nvim_get_current_tabpage()
	local list = state.list(tab)
	if #list == 0 then
		vim.notify("no terminal in this workspace", vim.log.levels.INFO)
		return
	end
	vim.ui.select(list, {
		prompt = "Terminal: ",
		format_item = function(bufnr)
			return buf_label(bufnr)
		end,
	}, function(bufnr)
		if bufnr then
			M.open(bufnr)
		end
	end)
end

--- winbar chip 与侧栏行尾共用的关闭字形
---@return string
function M.close_icon()
	return opts.close_icon
end

--- 还活着的终端总数（侧栏是全量列表，所以按全局算）
---@return integer
local function total_terms()
	local n = 0
	for _, tab in ipairs(state.tabs()) do
		n = n + #state.list(tab)
	end
	return n
end

--- 结束终端（默认当前）并收掉它的窗口
--- 关掉之后：一个终端都不剩就整个收起终端界面；还有别的终端则把焦点交给
--- 列表里的上一个（没有上一个就下一个），免得面板/侧栏落在空窗口上把布局弄歪。
---@param target integer|nil
function M.kill(target)
	local bufnr = target
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		bufnr = api.nvim_get_current_buf()
	end
	if not vim.b[bufnr].tw_term then
		return
	end

	local tab = state.tab_of(bufnr) or api.nvim_get_current_tabpage()
	-- 先记下它在列表里的位置：关掉后优先回到它上面那个
	local list = state.list(tab)
	local idx = 0
	for i, b in ipairs(list) do
		if b == bufnr then
			idx = i
		end
	end
	local successor = (idx > 1 and list[idx - 1]) or list[idx + 1]

	state.remove(bufnr)

	-- 面板窗口里显示的就是要关的这个终端时，直接把窗口换成后继终端：
	-- 否则窗口先被 hide、回头再 split 重建，侧栏会被当成基准窗口切一刀，跑到上面去
	local panel_win
	if successor and api.nvim_buf_is_valid(successor) then
		for _, win in ipairs(fn.win_findbuf(bufnr)) do
			if api.nvim_win_is_valid(win) and vim.w[win].tw_term_panel then
				panel_win = win
			end
		end
	end
	if panel_win then
		state.active(tab, successor)
		attach(panel_win, successor, tab)
	end

	for _, win in ipairs(fn.win_findbuf(bufnr)) do
		if api.nvim_win_is_valid(win) then
			if #api.nvim_tabpage_list_wins(api.nvim_win_get_tabpage(win)) > 1 then
				api.nvim_win_hide(win)
			else
				api.nvim_win_call(win, function()
					vim.cmd("enew")
				end)
			end
		end
	end
	pcall(api.nvim_buf_delete, bufnr, { force = true })

	if total_terms() == 0 then
		-- 最后一个终端没了：面板 + 侧栏一起收起，不留「没有终端」占位行
		hide_panel(tab)
		redraw()
		return
	end

	if panel_win and api.nvim_win_is_valid(panel_win) then
		-- 布局原地不动，只把焦点交给上一个终端
		api.nvim_set_current_win(panel_win)
		if opts.sidebar then
			sidebar.open(panel_win, tab)
		end
		if opts.startinsert and fn.mode() ~= "t" then
			vim.cmd.startinsert()
		end
		redraw()
		return
	end

	if successor and api.nvim_buf_is_valid(successor) and vim.b[successor].tw_term then
		M.open(successor)
	else
		redraw()
	end
end

--- 面板高度（winfix_guard 维持布局用）
---@return integer
function M.panel_size()
	return opts.size
end

--- 切换 winbar 标签栏显示
function M.toggle_tabs()
	opts.show_tabs = not opts.show_tabs
	refresh_winbars()
end

----------------------------------------------------------------------
-- setup
----------------------------------------------------------------------

---@param o? FeatTerminalConfig
function M.setup(o)
	opts = vim.tbl_deep_extend("force", opts, o or {})

	define_hl()
	sidebar.setup(M)
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = api.nvim_create_augroup("FeatTerminalHl", { clear = true }),
		callback = define_hl,
	})

	local group = api.nvim_create_augroup("FeatTerminal", { clear = true })

	-- 焦点变化：面板/侧栏的背景要在亮/暗两套之间切（对齐主题的 dim_inactive）
	api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
		group = group,
		callback = function()
			vim.schedule(highlights.update_windows)
		end,
	})

	-- 切 tab：侧栏高亮 / 光标要跟着当前工作区走
	api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			vim.schedule(redraw)
		end,
	})

	-- 关 tab：这个 tab 的终端跟着结束（进程不跨 workspace 存活）
	api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			vim.schedule(function()
				for _, bufnr in ipairs(state.sweep()) do
					if api.nvim_buf_is_valid(bufnr) then
						pcall(api.nvim_buf_delete, bufnr, { force = true })
					end
				end
				redraw()
			end)
		end,
	})

	-- 任何 :terminal（包括手动敲的）都算当前 tab 的终端：补登记 + 挂快捷键
	api.nvim_create_autocmd("TermOpen", {
		group = group,
		callback = function(args)
			local bufnr = args.buf
			if not vim.b[bufnr].tw_term then
				local index = state.next_index()
				vim.b[bufnr].tw_term = true
				vim.b[bufnr].tw_term_index = index
				vim.b[bufnr].tw_term_cwd = fn.getcwd()
				pcall(api.nvim_buf_set_name, bufnr, term_name(index))
				vim.bo[bufnr].filetype = FT
				vim.bo[bufnr].buflisted = false
				state.add(api.nvim_get_current_tabpage(), bufnr)
			end
			set_term_keymaps(bufnr)
			vim.schedule(redraw)
		end,
	})

	-- 终端进程退出后 buffer 留着（能看到最后输出），从登记表移除但保留窗口
	api.nvim_create_autocmd("TermClose", {
		group = group,
		callback = function(args)
			if vim.b[args.buf].tw_term then
				vim.schedule(redraw)
			end
		end,
	})

	-- 窗口尺寸变化时不动高度：用户自己 :resize 的结果要留着
	vim.keymap.set({ "n", "t" }, "<C-;>", function()
		M.toggle()
	end, { desc = "终端: 显示/隐藏当前工作区终端" })
	vim.keymap.set("n", "<leader>Ts", function()
		M.select()
	end, { desc = "终端: 选择" })
	vim.keymap.set("n", "<leader>Tn", function()
		M.rename()
	end, { desc = "终端: 重命名" })
	vim.keymap.set("n", "<leader>TN", function()
		M.new()
	end, { desc = "终端: 新建（当前工作区目录）" })
	vim.keymap.set("n", "<leader>To", function()
		M.toggle()
	end, { desc = "终端: 切换终端窗口" })
	vim.keymap.set("n", "<leader>Tt", function()
		M.toggle_tabs()
	end, { desc = "终端: 切换标签栏" })
	vim.keymap.set("n", "<leader>Tk", function()
		M.kill()
	end, { desc = "终端: 结束当前终端" })
	vim.keymap.set("n", "<leader>TK", function()
		local tab = api.nvim_get_current_tabpage()
		for _, bufnr in ipairs(state.list(tab)) do
			M.kill(bufnr)
		end
	end, { desc = "终端: 结束本工作区全部终端" })
end

return M
