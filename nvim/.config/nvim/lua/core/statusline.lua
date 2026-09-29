-- TODO: https://github.com/neovim/neovim/issues/34562

local colors = require("user.colors").palette
local lsp = require("lsp-config.statusline").lsp
local todo_status = require("todo2.ui.statusline")
local dap_status = require("dap").status()

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
	local unsaved_count = 0
	local has_unsaved = false

	-- 定义需要忽略的缓冲区类型和文件类型
	local ignore = {
		filetype = {
			"dap",
			"fugitive",
			"terminal",
			"log",
			"help",
			"dapui-scopes",
			"dapui-stacks",
			"dapui-breakpoints",
			"dapui-watches",
			"dap-repl",
			"dapui-console",
			"snacks_picker_input",
			"pager",
			"msgmore",
			"*.todo.md",
			"neo-tree-popup",
		},
		buftype = {
			"terminal",
			"nofile",
			"quickfix",
			"qf",
		},
		bufname = {
			"dap-terminal",
		},
	}

	-- 遍历所有缓冲区
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
		local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
		local name = vim.fn.bufname(buf)

		-- 检查是否在忽略列表
		local ignore_ft = vim.list_contains(ignore.filetype, ft)
		local ignore_bt = vim.list_contains(ignore.buftype, bt)

		-- bufname 用 match，避免完整路径不匹配
		local ignore_name = false
		for _, pat in ipairs(ignore.bufname) do
			if name:match(pat) then
				ignore_name = true
				break
			end
		end

		-- 如果是当前 buffer，进行额外检查
		if buf == 0 then
			local current_ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
			local current_bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
			local current_name = vim.fn.bufname(buf)

			-- 检查当前 buffer 是否应该被忽略
			local current_ignore_ft = vim.list_contains(ignore.filetype, current_ft)
			local current_ignore_bt = vim.list_contains(ignore.buftype, current_bt)

			local current_ignore_name = false
			for _, pat in ipairs(ignore.bufname) do
				if current_name:match(pat) then
					current_ignore_name = true
					break
				end
			end

			if current_ignore_ft or current_ignore_bt or current_ignore_name then
				return "" -- 如果当前 buffer 也在黑名单中，直接返回空
			end
		end

		if ignore_ft or ignore_bt or ignore_name then
			goto continue
		end

		-- 检查缓冲区是否已修改
		local modified = vim.api.nvim_get_option_value("modified", { buf = buf })
		if modified then
			unsaved_count = unsaved_count + 1
			has_unsaved = true
		end

		::continue::
	end

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
		state.vcs .. "  ",
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

local function apply()
	if vim.o.laststatus == 0 then
		return
	end
	if not should_update_statusline() then
		return
	end
	if update() then
		vim.o.statusline = compose()
		vim.cmd("redrawstatus")
	end
end

-- 初始构建
enqueue()
apply()

-- 被动兜底：每 1s 全量重建一次（捕获 gitsigns/todo/dap 等遗漏变化）
local function passive_loop()
	enqueue()
	apply()
	vim.defer_fn(passive_loop, 1000)
end
vim.defer_fn(passive_loop, 1000)

-- ================================
-- 事件驱动刷新
-- ================================
local statusline_group = vim.api.nvim_create_augroup("Statusline", { clear = true })

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

-- LSP spinner tick（由 lsp-config.statusline 发出）
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
