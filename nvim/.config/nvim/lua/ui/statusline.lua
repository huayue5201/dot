-- TODO: https://github.com/neovim/neovim/issues/34562

local colors = require("ui.colors").palette
local lsp = require("lsp_ext.statusline").lsp
local todo_status = require("todo2.ui.statusline")
local upstream = require("feat.fork_upstream")

local M = {} -- 使用 M 作为模块的局部变量

-- ================================
-- 高亮组配置
-- ================================
local highlight_defs = {
	DefaultMode = { bold = true },

	-- 保存状态相关
	SaveHighlight = { fg = "#E4080A", bold = true }, -- 未保存数量的红色数字
	SaveDotDirty = { fg = "#E4080A", bold = true }, -- 当前 buffer 未保存（红点）
	SaveDotClean = { fg = "#50fa7b", bold = true }, -- 当前 buffer 已保存（绿点）

	-- 模式高亮
	NormalMode = { bold = true },
	InsertMode = { bold = true },
	VisualMode = { bold = true },
	ReplaceMode = { bold = true },

	-- 其他高亮
	PinkHighlight = { fg = "#ffde7d", bold = true },
	StatuslineIcon = { fg = "#ffc125", bold = true },
	DapIcon = { fg = "#FF0000", bold = true },
	GitIcon = { fg = "#FF8C00", bold = true },
	GitIconChanged = { fg = colors.yellow, bold = true },
	GitIconRemoved = { fg = colors.red, bold = true },
	GitIconAdded = { fg = colors.green, bold = true },
}

for group, opts in pairs(highlight_defs) do
	vim.api.nvim_set_hl(0, group, opts)
end

-- ================================
-- 模式配置
-- ================================
-- 更完整的 MODES 表（基于 :help mode() 列出的可能返回值）
local MODES = {
	-- Normal
	["n"] = { label = "NORMAL", hl = "NormalMode" },
	["no"] = { label = "N·OP_PENDING", hl = "NormalMode" },

	-- Visual
	["v"] = { label = "VISUAL", hl = "VisualMode" },
	["V"] = { label = "V-LINE", hl = "VisualMode" }, -- visual line
	["\22"] = { label = "V-BLOCK", hl = "VisualMode" }, -- visual block (Ctrl-V). \22 is the ASCII for Ctrl-V

	-- Select (select mode, rarely used)
	["s"] = { label = "SELECT", hl = "VisualMode" },
	["S"] = { label = "S-LINE", hl = "VisualMode" },
	["\19"] = { label = "S-BLOCK", hl = "VisualMode" }, -- Ctrl-S (if appears)

	-- Insert / Replace / Command / Terminal
	["i"] = { label = "INSERT", hl = "InsertMode" },
	["ic"] = { label = "INSERT", hl = "InsertMode" }, -- insert completion
	["ix"] = { label = "INSERT", hl = "InsertMode" }, -- insert mapping

	["R"] = { label = "REPLACE", hl = "ReplaceMode" },
	["Rv"] = { label = "V-REPLACE", hl = "ReplaceMode" }, -- virtual replace?

	["c"] = { label = "COMMAND", hl = "DefaultMode" },
	["cv"] = { label = "VIM EX", hl = "DefaultMode" }, -- Ex mode from vim
	["ce"] = { label = "EX", hl = "DefaultMode" },

	-- Hit-enter prompt, more prompt-like states
	["r"] = { label = "PROMPT", hl = "DefaultMode" }, -- hit-enter prompt, etc.
	["rm"] = { label = "MORE", hl = "DefaultMode" }, -- more-mode (for r? etc)
	["r?"] = { label = "CONFIRM", hl = "DefaultMode" },

	-- Operator-pending (after typed operator like d, c, y)
	["o"] = { label = "OP-PENDING", hl = "DefaultMode" },

	-- Terminal mode
	["t"] = { label = "TERMINAL", hl = "DefaultMode" },
}

-- ================================
-- 滚动条图标
-- ================================
local PROGRESS_ICONS = {
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
	" ",
}

-- ================================
-- 核心功能函数
-- ================================
-- 更鲁棒的 mode 显示函数
function M.mode()
	-- 使用 nvim_get_mode().mode，它返回精确的模式字符串（可能是多字符）
	local current_mode = vim.api.nvim_get_mode().mode

	-- 试直接匹配完整模式（优先精确匹配）
	local mode_info = MODES[current_mode]
	if not mode_info then
		-- 如果没有精确匹配，尝试用第一个字符做退化匹配（如 "niI" -> "n"）
		local short = current_mode:sub(1, 1)
		mode_info = MODES[short] or { label = current_mode, hl = "DefaultMode" }
	end

	-- 返回带高亮的文本
	return "%#StatuslineIcon# %*"
		.. "%#"
		.. mode_info.hl
		.. "#"
		.. mode_info.label
		.. "%#StatuslineIcon#  %*"
		.. "%#"
		.. mode_info.hl
		.. "#"
		.. "%*"
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
		dot = "%#SaveDotDirty#%*" -- 未保存：红色
	else
		dot = "%#SaveDotClean#%*" -- 已保存：绿色
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
	return "%#DapIcon# %*" .. dap_status
end

--- 获取 Git 状态
local function vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		-- return "%#GitIcon# %*" .. " "
		return "%#GitIcon# %*"
	end

	local parts = { "%#GitIcon# %*" .. git_info.head }

	local git_icons = {
		added = "%#GitIconAdded#+%*",
		removed = "%#GitIconRemoved#-%*",
		changed = "%#GitIconChanged# %*",
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
		return "%#PinkHighlight#" .. PROGRESS_ICONS[#PROGRESS_ICONS] .. "%*"
	end

	local progress = (cur_line - 1) / (total_lines - 1)
	local icon_index = math.ceil(progress * (#PROGRESS_ICONS - 1)) + 1
	return "%#PinkHighlight#" .. PROGRESS_ICONS[icon_index] .. "%*"
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
	return string.format("%%#StatuslineIcon# %%#Normal#%d ", count)
end

-- ================================
-- 状态栏组装（高性能版：缓存 + 事件驱动）
-- ================================

-- 各模块构建函数
local builders = {
	mode = M.mode,
	save = save_status,
	lsp = lsp,
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
local function compose()
	return table.concat({
		"%#Normal#",
		state.mode .. "  ",
		state.save,
		"   ",
		state.lsp,
		"%=", -- 分隔符
		state.todo,
		state.dap .. " ",
		state.vcs .. "",
		state.upstream == "" and "" or (state.upstream .. " "),
		" %l:%c   ",
		state.scroll,
		"%p ",
	})
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

-- 模式变化：只更新模式
vim.api.nvim_create_autocmd("ModeChanged", {
	group = statusline_group,
	callback = function()
		enqueue("mode")
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
