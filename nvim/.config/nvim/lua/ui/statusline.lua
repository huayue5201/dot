-- TODO: https://github.com/neovim/neovim/issues/34562

local icons = require("ui.icons")
local lsp = require("lsp_ext.statusline").lsp
local todo_status = require("todo2.ui.statusline")
local upstream = require("feat.fork_upstream")

local M = {} -- 使用 M 作为模块的局部变量

-- 图标在 lua/ui/icons.lua，配色在 lua/ui/colors.lua
local ICONS = icons.icon
local C = require("ui.colors").color

-- ================================
-- 高亮组配置
-- ================================
local highlight_defs = {
	DefaultMode = { bold = true },

	-- 保存状态相关
	SaveHighlight = { fg = C.save_dirty, bold = true }, -- 未保存数量的红色数字
	SaveDotDirty = { fg = C.save_dirty, bold = true }, -- 当前 buffer 未保存（红点）
	SaveDotClean = { fg = C.save_clean, bold = true }, -- 当前 buffer 已保存（绿点）

	-- 其他高亮
	PinkHighlight = { fg = C.pink, bold = true },
	StatuslineIcon = { fg = C.icon, bold = true },
	DapIcon = { fg = C.dap, bold = true },
	GitIcon = { fg = C.git, bold = true },
	GitIconChanged = { fg = C.git_changed, bold = true },
	GitIconRemoved = { fg = C.git_removed, bold = true },
	GitIconAdded = { fg = C.git_added, bold = true },

	-- 段间分隔符（低对比，只做视觉分界）
	StlSep = { fg = C.sep },

	-- 数据库工作台（sqmeow）窗口角色
	DbIcon = { fg = C.db_icon, bold = true },
	DbLocked = { fg = C.db_locked, italic = true },
}

-- 工作区锚点：每个根目录固定占一个槽位（颜色 = 一眼区分「我在哪」），
-- 槽位顺序与 ui.colors 的 M.color.ws 一一对应（StlWs1..6）
for i, fg in ipairs(C.ws) do
	highlight_defs["StlWs" .. i] = { fg = fg, bold = true }
end

for group, opts in pairs(highlight_defs) do
	vim.api.nvim_set_hl(0, group, opts)
end

-- ================================
-- 保存提示功能
-- ================================
local function save_status()
	local unsaved_count = require("feat.unsaved").count()
	local has_unsaved = unsaved_count > 0

	-- 当前 buffer 是否已保存
	local current_modified = vim.api.nvim_get_option_value("modified", { buf = 0 })

	-- 状态点（变色）
	local dot
	if current_modified then
		dot = "%#SaveDotDirty#" .. ICONS.save_dot .. "%*" -- 未保存：红色
	else
		dot = "%#SaveDotClean#" .. ICONS.save_dot .. "%*" -- 已保存：绿色
	end

	-- 设置图标和计数
	local label = "save."
	local count_text = string.format("%d", unsaved_count)

	-- 高亮数字部分
	if has_unsaved then
		return string.format("%s%s%%#SaveHighlight#%s%%*", dot, label, count_text)
	else
		return string.format("%s%s%s", dot, label, count_text)
	end
end

--- 获取调试器状态
local function dap()
	-- dap 只在真正调试时才需要，延迟到状态栏渲染时再加载（启动期省掉 dap/dap-view 初始化）
	if package.loaded["dap"] == nil then
		return ""
	end
	local dap_status = require("dap").status()
	if dap_status == "" then
		return ""
	end
	return "%#DapIcon#" .. ICONS.dap .. " %*" .. dap_status
end

--- 获取 Git 状态
local function vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return "%#GitIcon#" .. ICONS.git_branch .. " %*"
	end

	local parts = { "%#GitIcon#" .. ICONS.git_branch .. " %*" .. git_info.head }

	local git_icons = {
		added = "%#GitIconAdded#+%*",
		removed = "%#GitIconRemoved#-%*",
		changed = "%#GitIconChanged#" .. ICONS.git_changed .. " %*",
	}

	for key, icon in pairs(git_icons) do
		if git_info[key] and git_info[key] > 0 then
			table.insert(parts, icon .. git_info[key])
		end
	end

	return table.concat(parts, " ") .. " "
end

--- 获取动态滚动条
local function get_scrollbar()
	local total_lines = vim.api.nvim_buf_line_count(0)
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]

	if total_lines <= 1 then
		return "%#PinkHighlight#" .. ICONS.scroll_frames[#ICONS.scroll_frames] .. "%*"
	end

	local progress = (cur_line - 1) / (total_lines - 1)
	local icon_index = math.ceil(progress * (#ICONS.scroll_frames - 1)) + 1
	return "%#PinkHighlight#" .. ICONS.scroll_frames[icon_index] .. "%*"
end

-- ================================
-- ⭐ AI agent 状态（ask_agent 状态层）
-- ================================
-- ⚠ 等你（permission/question）/ ✓ 完成未看 / ✗ 失败 / ◐ 工作中；空串表示没有
-- 需要关注的实例，段自动消失。数据来自插件里的唯一状态层（:AskAgentDashboard
-- 看详情），这里只读数，不触发任何探测。
local function ai_status()
	local ok, ask = pcall(require, "ask_agent")
	if not ok then
		return ""
	end
	local out = ask.statusline()
	if out == "" then
		return ""
	end
	return string.format("%%#StatuslineIcon#%s%%* %s ", ICONS.ai, out)
end

-- ================================
-- ⭐ TODO 标记数量显示
-- ================================
local function todo_markers()
	-- ⭐ 修复：获取当前 buffer 的文件路径
	local bufnr = vim.api.nvim_get_current_buf()
	local filepath = vim.api.nvim_buf_get_name(bufnr)

	-- ⭐ 修复：传递 filepath 参数
	local count = todo_status.get_marker_count(filepath)

	if count == 0 then
		return ""
	end
	-- 使用 StatuslineIcon 高亮组保持一致
	return string.format("%%#StatuslineIcon#%s %%*%d ", ICONS.todo, count)
end

-- ================================
-- 数据库工作台窗口角色（sqmeow）
-- ================================
-- 插件的 drawer / 结果 grid 窗口被 'winfixbuf' 锁在自己的 buffer 上（ui/layout.lua 的
-- M.fixbuf），跳转或 :edit 会被 Neovim 拒绝。锁是窗口级不变量，用户平时看不见，
-- 只有被拒绝时才暴露，所以状态栏只负责说清「这个窗口是什么」，锁状态作为后缀。
-- 注意：vim.o.statusline 是全局字符串，普通缓存段无法按窗口区分高低，这里必须用
-- %{%...%} 表达式段，由 Neovim 在绘制时按 g:statusline_winid 逐窗口求值。
local DB_ROLES = {
	["sqmeow-drawer"] = "DRAWER",
	["sqmeow-result"] = "GRID",
	["sqmeow-row"] = "ROW",
	["sqmeow-filter"] = "FILTER",
	["sqmeow-form"] = "FORM",
	["sqmeow-relationships"] = "RELATIONS",
	["sqmeow-structure"] = "STRUCTURE",
}

-- P2 扩展点：调用方按需设置某窗口的附加信息（如 "rows 100/24,310"）
local db_extra = {}

--- 设置某个窗口在数据库段后追加的文本（传 nil 清除）
---@param win integer
---@param text string|nil
function M.set_db_extra(win, text)
	db_extra[win] = text
end

--- 当前窗口的数据库角色段（空字符串表示不是插件窗口）
---@return string
function M.db()
	local ok, out = pcall(function()
		-- 必须用 g:statusline_winid：惰性重绘 / drawer 聚焦时它与当前窗口会分叉
		local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
		if not vim.api.nvim_win_is_valid(win) then
			return ""
		end
		local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
		local role = DB_ROLES[filetype]
		if not role then
			return ""
		end

		local parts = { "%#DbIcon#" .. role .. "%*" }

		-- winfixbuf 只有 0.11+ 才有，裸读会报错；普通编辑窗口允许一次跳走
		if vim.fn.exists("&winfixbuf") == 1 and vim.wo[win].winfixbuf then
			table.insert(parts, "%#DbLocked#" .. ICONS.db_lock .. "locked%*")
		end

		local extra = db_extra[win]
		if extra and extra ~= "" then
			table.insert(parts, " " .. extra)
		end

		return " " .. table.concat(parts, "") .. " "
	end)
	return ok and out or ""
end

-- ================================
-- 工作区锚点（每个 tab = 一个工作区，根目录见 ~/neovim-plugins/tab-workspace.nvim/lua/tab_workspace/root.lua）
-- ================================
-- 状态栏是全局字符串，切 tab 不会自动重算，靠下方 TabEnter / DirChanged 刷新。
-- 颜色槽位固定为 StlWs1..6：同一个根目录永远同一个颜色，且不动态创建高亮组。
local WS_SLOTS = 6

--- 根目录 -> 固定槽位（稳定哈希，便宜）
---@param dir string
---@return integer
local function ws_slot(dir)
	local h = 0
	for i = 1, #dir do
		h = (h * 31 + dir:byte(i)) % 1000003
	end
	return h % WS_SLOTS + 1
end

local function workspace()
	local ok, out = pcall(function()
		-- 必须按 statusline_winid 取所在 tab：惰性重绘时当前窗口可能已经不是它
		local tab = vim.api.nvim_get_current_tabpage()
		local win = tonumber(vim.g.statusline_winid)
		if win and vim.api.nvim_win_is_valid(win) then
			tab = vim.api.nvim_win_get_tabpage(win)
		end
		local number = vim.api.nvim_tabpage_get_number(tab)
		local ok_ws, ws = pcall(require, "tab_workspace")
		if not ok_ws then
			return ""
		end
		local dir = (ws.root(tab):gsub("/+$", ""))
		local name = (ws.workspace_name(tab):gsub("%%", "%%%%"))

		-- 只高亮图标，名字用普通文本（避免整段彩色块）
		local parts = { string.format("%%#StlWs%d#%s%%* %s", ws_slot(dir), ICONS.ws, name) }

		-- 已锁定（<leader>lws 显式设根 / <leader>lwr 回退）：自动跟随不再改它
		if ws.root_pinned(tab) then
			table.insert(parts, "%#StlSep#" .. ICONS.ws_lock .. "%*")
		end

		-- 附加了辅助根（多根工作区）：+N；用 <leader>ew 看并列的多根树
		local extra = #ws.aux_roots(tab)
		if extra > 0 then
			table.insert(parts, string.format("%%#StlSep#+%d%%*", extra))
		end

		local tabs = #vim.api.nvim_list_tabpages()
		if tabs > 1 then
			table.insert(parts, string.format("%%#StlSep#%d/%d%%*", number, tabs))
		end

		return " " .. table.concat(parts, " ") .. " "
	end)
	return ok and out or ""
end

-- ================================
-- 状态栏组装（高性能版：缓存 + 事件驱动）
-- ================================

-- 各模块构建函数
local builders = {
	ws = workspace,
	save = save_status,
	lsp = lsp,
	ai = ai_status,
	todo = todo_markers,
	dap = dap,
	vcs = vcs,
	upstream = upstream.component,
	scroll = get_scrollbar,
}

-- 渲染结果缓存 + 脏标记
local state = {}
local dirty = {}

--- 标记模块（或全部）为脏
local function enqueue(module)
	if module then
		dirty[module] = true
	else
		for mod in pairs(builders) do
			dirty[mod] = true
		end
	end
end

--- 只重建脏模块，返回是否有变化
local function update()
	local changed = false
	for mod in pairs(dirty) do
		local builder = builders[mod]
		if builder then
			local value = builder()
			if value ~= state[mod] then
				state[mod] = value
				changed = true
			end
		end
		dirty[mod] = nil
	end
	return changed
end

--- 拼接最终状态栏（%l/%c/%p 由 Neovim 在绘制时展开，无需 Lua 计算）
--- 分隔策略：builder 只负责内容，不负责空格；段间的空格统一在这里加。
--- 左侧（ws/save/lsp）用两个空格，右侧分组之间用 dim 的 │，尾部
--- 行列/滚动条/百分比视为一块，内部仍用空格。
local SEP = " %#StlSep#" .. ICONS.sep .. "%* "

--- 去掉段内容首尾的空白（builder 历史上各自带不同数量的尾随空格）
---@param value string
---@return string
local function trimmed(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- 拼一组段，空段直接跳过，不留多余分隔符
---@param pieces string[]
---@param sep string
---@return string
local function join(pieces, sep)
	local kept = {}
	for _, piece in ipairs(pieces) do
		local text = trimmed(piece)
		if text ~= "" then
			table.insert(kept, text)
		end
	end
	return table.concat(kept, sep)
end

local function compose()
	local tail = "%l:%c  " .. state.scroll .. " " .. "%p"
	local right = join({
		state.ai,
		state.todo,
		state.dap,
		"%{%v:lua.Statusline.db()%}",
		state.vcs,
		state.upstream,
		tail,
	}, SEP)

	-- 工作区固定在最左（自带文件夹图标 + 按根目录哈希的配色）：切 tab 第一眼
	-- 看到的就是「我在哪个项目」；状态模块全空时也不会留下悬空分隔符
	local left = join({ state.ws, state.save, state.lsp }, "  ")

	-- 整条状态栏只用 StatusLine 一种底色：`%*` 复位到 StatusLine。不要用
	-- `%#Normal#`——Normal 的 bg 与 StatusLine 不同，会在左边段与 `%=` 填充区
	-- 之间留下一条颜色不一样的「断口」。
	return "%*" .. left .. "%*%=" .. right .. " "
end

--- 应用：重建脏模块 -> 更新 statusline -> 重绘
--- 注意：只在状态栏内容真正变化时才 redrawstatus。
--- 无条件 redrawstatus 会在每次 CursorMoved/CursorMovedI 时触发（例如在 fff 等
--- 浮动输入框里打字时），虽然不应移动光标，但属于无谓的重绘。

--- 判断当前窗口是否需要更新状态栏。
--- 浮动窗口（如 fff 输入框）与特殊 buffer（prompt/nofile/terminal/quickfix 等）
--- 不显示状态栏；在这些窗口里 redrawstatus 会触发 neovim#34562，导致光标意外左移。
local function should_update_statusline()
	local bt = vim.api.nvim_get_option_value("buftype", { buf = 0 })
	if bt ~= "" then
		return false
	end
	local cfg = vim.api.nvim_win_get_config(0)
	if cfg.relative ~= "" then
		return false
	end
	return true
end

--- 重绘合并：切 tab 时 BufEnter/WinEnter 早于 TabEnter 触发，而这里同步
--- redrawstatus 会在 tab_workspace 改好 buflisted 之前强制画一帧，导致 tabline
--- 先显示上一个 tab 的 buffer 再刷新（闪烁）。改为一轮事件循环里只重绘一次，
--- 让 TabEnter 里的 relist 先跑完。
local redraw_pending = false
local function schedule_redrawstatus()
	if redraw_pending then
		return
	end
	redraw_pending = true
	vim.schedule(function()
		redraw_pending = false
		if should_update_statusline() then
			pcall(vim.cmd, "redrawstatus")
		end
	end)
end

local function apply()
	if vim.o.laststatus == 0 then
		return
	end
	if not should_update_statusline() then
		return
	end
	if update() then
		vim.o.statusline = compose()
		schedule_redrawstatus()
	end
end

-- 初始构建
enqueue()
apply()

-- 兜底刷新：不再每秒全量重建，改成「空闲时补一次」（CursorHold 默认 4s 无输入）。
-- update() 只在值真正变化时才写 statusline，所以没变化时这里是纯比较，几乎零成本。
-- 覆盖那些没有事件可听的模块（todo2 计数、dap 状态）。
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained" }, {
	group = vim.api.nvim_create_augroup("StatuslineIdle", { clear = true }),
	callback = function()
		enqueue()
		apply()
	end,
})

-- ================================
-- 事件驱动刷新
-- ================================
local statusline_group = vim.api.nvim_create_augroup("Statusline", { clear = true })

-- 工作区锚点：切 tab（TabEnter）/ :tcd（DirChanged）/ 根与辅助根变化时重算
vim.api.nvim_create_autocmd({ "TabEnter", "DirChanged" }, {
	group = statusline_group,
	callback = function()
		enqueue("ws")
		apply()
	end,
})

-- pin / 辅助根的增减不一定伴随 :tcd（例如 <leader>lw+ 只是加了个附加根）
vim.api.nvim_create_autocmd("User", {
	pattern = { "TabWorkspaceRoot", "TabWorkspaceRoots", "TabWorkspaceName" },
	group = statusline_group,
	callback = function()
		enqueue("ws")
		apply()
	end,
})

-- ask_agent 状态变化：插件已经做了 2s 轮询 + 事件，这里只重绘，不额外探测
vim.api.nvim_create_autocmd("User", {
	pattern = "AskAgentStateChanged",
	group = statusline_group,
	callback = function()
		enqueue("ai")
		apply()
	end,
})

-- gitsigns 更新（status_dict 变了但 buffer 没动，如后台 fetch / index 完成）
vim.api.nvim_create_autocmd("User", {
	pattern = "GitSignsUpdate",
	group = statusline_group,
	callback = function()
		enqueue("vcs")
		apply()
	end,
})

-- 滚动（鼠标/<C-e> 等没有移动光标的情况）
vim.api.nvim_create_autocmd("WinScrolled", {
	group = statusline_group,
	callback = function()
		enqueue("scroll")
		apply()
	end,
})

-- 光标移动：只更新滚动条（便宜）
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
	group = statusline_group,
	callback = function()
		enqueue("scroll")
		apply()
	end,
})

-- 缓冲区/修改状态变化
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "BufAdd", "BufDelete", "BufWipeout", "BufWritePost" }, {
	group = statusline_group,
	callback = function()
		enqueue("save")
		enqueue("vcs")
		enqueue("todo")
		enqueue("lsp")
		enqueue("upstream")
		-- 滚动条是 Lua 算的（不像 %l/%p 由 Neovim 绘制时展开），换 buffer/窗口必须重算，
		-- 否则会一直显示上一个 buffer 的进度位置。
		enqueue("scroll")
		apply()
	end,
})

-- modified 标志变化（首次编辑/保存时触发）
vim.api.nvim_create_autocmd("OptionSet", {
	pattern = "modified",
	group = statusline_group,
	callback = function()
		enqueue("save")
		apply()
	end,
})

-- LSP 客户端 attach/detach
vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
	group = statusline_group,
	callback = function()
		enqueue("lsp")
		apply()
	end,
})

-- 诊断变化：防抖 200ms
local diag_pending = false
vim.api.nvim_create_autocmd("DiagnosticChanged", {
	group = statusline_group,
	callback = function()
		if diag_pending then
			return
		end
		diag_pending = true
		vim.defer_fn(function()
			diag_pending = false
			enqueue("lsp")
			apply()
		end, 200)
	end,
})

-- 窗口关掉时清掉它的数据库附加信息，避免 winid 被复用时串台
vim.api.nvim_create_autocmd("WinClosed", {
	group = statusline_group,
	callback = function(ev)
		db_extra[tonumber(ev.match)] = nil
	end,
})

-- 上游状态更新（由 fork-upstream 模块发出）
vim.api.nvim_create_autocmd("User", {
	pattern = "ForkUpstreamUpdate",
	group = statusline_group,
	callback = function()
		enqueue("upstream")
		apply()
	end,
})

-- LSP spinner tick（由 lsp_ext.statusline 发出）
vim.api.nvim_create_autocmd("User", {
	pattern = "LspStatusSpinner",
	group = statusline_group,
	callback = function()
		enqueue("lsp")
		apply()
	end,
})

-- 将模块设置为全局变量，确保状态栏可以访问
_G.Statusline = M

return M
