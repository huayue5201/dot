-- TODO https://github.com/neovim/neovim/issues/34562

local utils = require("user.utils")
local colors = utils.palette
local lsp = require("lsp-config.lsp_status_mod").lsp
require("user.search_status").setup()
local search_status = require("user.search_status")
local todo_status = require("todo2.ui.statusline")

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
function M.save_status()
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
		local ignore_ft = vim.tbl_contains(ignore.filetype, ft)
		local ignore_bt = vim.tbl_contains(ignore.buftype, bt)

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
			local current_ignore_ft = vim.tbl_contains(ignore.filetype, current_ft)
			local current_ignore_bt = vim.tbl_contains(ignore.buftype, current_bt)

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
function M.dap_status()
	local dap_status = require("dap").status()
	if dap_status == "" then
		return ""
	end
	return "%#DapIcon# %*" .. dap_status
end

--- 获取 Git 状态
function M.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return "%#GitIcon# %*" .. " "
	end

	local parts = { "%#GitIcon# %*" .. "[" .. git_info.head .. "]" }

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
function M.get_scrollbar()
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
function M.todo_markers()
	local count = todo_status.get_marker_count()
	if count == 0 then
		return ""
	end
	-- 使用 StatuslineIcon 高亮组保持一致
	return string.format("%%#StatuslineIcon# %%#Normal#%d ", count)
end

-- ================================
-- 状态栏组装
-- ================================

--- 组装活动状态栏
function M.active()
	return table.concat({
		"%#Normal#",
		string.format("%-45s", M.mode()) .. "  ", -- 模式显示区域
		M.save_status(),
		"   ",
		lsp(),
		"%=", -- 分隔符
		M.todo_markers(), -- ⭐ 添加 TODO 标记数量显示
		search_status.get() .. " ",
		M.dap_status() .. " ",
		M.vcs() .. "  ",
		"%l%c   ",
		M.get_scrollbar(),
		"%p ",
	})
end

-- ================================
-- 初始化
-- ================================

--- 刷新状态栏
local function refresh_statusline()
	vim.api.nvim_set_option_value("statusline", "%!v:lua.Statusline.active()", {
		win = vim.api.nvim_get_current_win(),
	})
end

-- 创建自动命令组
local statusline_group = vim.api.nvim_create_augroup("Statusline", { clear = true })

-- 注册自动命令
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWritePost", "ModeChanged" }, {
	group = statusline_group,
	callback = refresh_statusline,
})

-- 将模块设置为全局变量，确保状态栏可以访问
_G.Statusline = M

return M
