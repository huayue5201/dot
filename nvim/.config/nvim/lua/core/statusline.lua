-- TODO https://github.com/neovim/neovim/issues/34562

local utils = require("user.utils")
local colors = utils.palette
local lsp = require("lsp.lsp_status_mod").lsp
require("user.search_status").setup()
local search_status = require("user.search_status")

local M = {} -- 使用 M 作为模块的局部变量

-- ================================
-- 高亮组配置
-- ================================
local function setup_highlights()
	local highlight_defs = {
		DefaultMode = { bold = true },
		SaveHighlight = { fg = "#f08080", bold = true }, -- 定义红色保存高亮组
		NormalMode = { bold = true },
		InsertMode = { bold = true },
		VisualMode = { bold = true },
		ReplaceMode = { bold = true },
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
	return "%#StatuslineIcon# %*" .. "%#" .. mode_info.hl .. "#" .. mode_info.label .. "%*"
end

-- ================================
-- 保存提示功能
-- ================================
function M.save_status()
	-- 获取所有打开的 buffer
	local buffers = vim.api.nvim_list_bufs()

	-- 遍历每个 buffer 检查是否有已修改的文件
	for _, buf in ipairs(buffers) do
		-- 如果该 buffer 已修改，显示保存提示
		if vim.api.nvim_get_option_value("modified", { buf = buf }) then
			return "%#SaveHighlight#󰆓 %*" .. " 保存"
		end
	end

	-- 如果所有 buffer 都未修改，显示一个空的保存图标
	return "󰆓 "
end

--- 获取调试器状态
function M.dap_status()
	local dap_status = require("dap").status()
	if dap_status == "" then
		return ""
	end
	return "%#DapIcon# %*" .. dap_status
end

--- 获取 Git 状态
function M.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return "%#GitIcon# %*" .. " "
	end

	local parts = { "%#GitIcon# %*" .. "[" .. git_info.head .. "]" }

	local git_icons = {
		added = "%#GitIconAdded#+%*",
		removed = "%#GitIconRemoved#-%*",
		changed = "%#GitIconChanged#󱅅 %*",
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

--- 获取芯片状态
function M.env()
	return require("env.core").EnvStatus() or ""
end

-- ================================
-- 状态栏组装
-- ================================

--- 组装活动状态栏
function M.active()
	return table.concat({
		"%#Normal#",
		string.format("%-45s", M.mode()) .. " ", -- 模式显示区域
		M.env() .. " ",
		M.save_status(),
		"  %y ",
		lsp(),
		"%=", -- 分隔符
		search_status.get() .. " ",
		M.dap_status() .. " ",
		M.vcs() .. "  ",
		"%l%c   ",
		"%p:",
		M.get_scrollbar(),
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

-- 设置高亮组
setup_highlights()

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
