-- TODO https://github.com/neovim/neovim/issues/34562

local utils = require("utils.utils")
local colors = utils.palette
local lsp_progress = require("utils.lsp_progress")

local M = {} -- 使用 M 作为模块的局部变量

-- ================================
-- 高亮组配置
-- ================================
local function setup_highlights()
	local highlight_defs = {
		DefaultMode = { bold = true },
		NormalMode = { bold = true },
		InsertMode = { bold = true },
		VisualMode = { bold = true },
		ReplaceMode = { bold = true },
		PinkHighlight = { fg = "#ffde7d", bold = true },
		StatuslineIcon = { fg = "#ffde7d", bold = true },
		LspIcon = { fg = "#4876FF", bold = true },
		DapIcon = { fg = "#FF0000", bold = true },
		GitIcon = { fg = "#6639a6", bold = true },
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
local MODES = {
	["n"] = { label = "NORMAL", hl = "NormalMode" },
	["i"] = { label = "INSERT", hl = "InsertMode" },
	["v"] = { label = "VISUAL", hl = "VisualMode" },
	["V"] = { label = "V-LINE", hl = "VisualMode" },
	[""] = { label = "V-BLOCK", hl = "VisualMode" },
	["R"] = { label = "REPLACE", hl = "ReplaceMode" },
	["c"] = { label = "COMMAND", hl = "DefaultMode" },
	["t"] = { label = "TERMINL", hl = "DefaultMode" },
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
-- LSP 诊断级别配置
-- ================================
local DIAGNOSTIC_SEVERITY = {
	[vim.diagnostic.severity.ERROR] = {
		icon = utils.icons.diagnostic.ERROR,
		hl = "DiagnosticError",
	},
	[vim.diagnostic.severity.WARN] = {
		icon = utils.icons.diagnostic.WARN,
		hl = "DiagnosticWarn",
	},
	[vim.diagnostic.severity.INFO] = {
		icon = utils.icons.diagnostic.INFO,
		hl = "DiagnosticInfo",
	},
	[vim.diagnostic.severity.HINT] = {
		icon = utils.icons.diagnostic.HINT,
		hl = "DiagnosticHint",
	},
}

-- ================================
-- 核心功能函数
-- ================================

--- 获取当前模式并应用高亮
function M.mode()
	local current_mode = vim.api.nvim_get_mode().mode
	local mode_info = MODES[current_mode] or { label = current_mode, hl = "DefaultMode" }
	return "%#StatuslineIcon# %*" .. "%#" .. mode_info.hl .. "#" .. mode_info.label .. "%*"
end

-- 定义高亮组（可放在 setup_highlights 函数里）
vim.api.nvim_set_hl(0, "HydraActive", { fg = "#ff5555", bold = true })
vim.api.nvim_set_hl(0, "HydraInactive", { fg = "#ffffff", bold = true })

-- Hydra 状态图标函数
function M.hydra_icon()
	local has_hydra, hydra = pcall(require, "hydra.statusline")
	if not has_hydra then
		return "" -- 没有安装 hydra 时不显示
	end

	if hydra.is_active() then
		return "%#HydraActive# %*" -- 红色图标（Hydra 启动中）
	else
		return "%#HydraInactive# %*" -- 白色图标（Hydra 未激活）
	end
end

--- 获取 LSP 客户端信息
function M.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

	if vim.tbl_isempty(buf_clients) then
		return "󰼎 "
	end

	-- 忽略列表，只是不显示名字，但数量要算
	local ignore_list = {
		"null-ls",
		"ruff",
		"ruff_lsp",
		"eslint",
		"GitHub Copilot",
		"copilot",
		"lua_ls",
	}

	-- 找主客户端（第一个不在 ignore 的）
	local main_client = buf_clients[1]
	for _, client in ipairs(buf_clients) do
		if not vim.tbl_contains(ignore_list, client.name) then
			main_client = client
			break
		end
	end

	local total_clients = #buf_clients -- 总数量，包括忽略的

	local num_icons = {
		[1] = "󰼏",
		[2] = "󰎨",
		[3] = "󰎫",
		[4] = "󰼒",
		[5] = "󰎯",
		[6] = "󰼔",
		[7] = "󰼕",
		[8] = "󰼖",
		[9] = "󰼗",
		[10] = "󰿪",
	}
	local icon = num_icons[total_clients] or "󰿪"

	return string.format("%s %s 󱞩", icon, main_client.name)
end

--- 获取 LSP 诊断信息
function M.lsp_diagnostics()
	if lsp_progress.is_loading() then
		return ""
	end

	local diagnostics = vim.diagnostic.get(0)
	if #diagnostics == 0 then
		return ""
	end

	-- 统计各严重级别的诊断数量
	local counts = {
		[vim.diagnostic.severity.ERROR] = 0,
		[vim.diagnostic.severity.WARN] = 0,
		[vim.diagnostic.severity.INFO] = 0,
		[vim.diagnostic.severity.HINT] = 0,
	}

	for _, diag in ipairs(diagnostics) do
		counts[diag.severity] = counts[diag.severity] + 1
	end

	-- 构建诊断组件
	local parts = {}
	local severity_order = {
		vim.diagnostic.severity.ERROR,
		vim.diagnostic.severity.WARN,
		vim.diagnostic.severity.INFO,
		vim.diagnostic.severity.HINT,
	}

	for _, severity in ipairs(severity_order) do
		local count = counts[severity]
		if count > 0 then
			local data = DIAGNOSTIC_SEVERITY[severity]
			table.insert(parts, "%#" .. data.hl .. "#" .. data.icon .. count .. "%*")
		end
	end

	return table.concat(parts, " ")
end

--- 获取完整的 LSP 状态
function M.lsp()
	return table.concat({
		M.lsp_clients(),
		" " .. lsp_progress.status(),
		M.lsp_diagnostics(),
	})
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
		return "%#GitIcon#   %*"
	end

	local parts = { "%#GitIcon# %*" .. git_info.head }

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
		string.format("%-45s", M.mode()), -- 模式显示区域
		M.hydra_icon() .. "  ",
		M.env() .. "  ",
		-- "%y ",
		M.lsp(),
		"%=", -- 分隔符
		M.dap_status() .. " ",
		M.vcs() .. " ",
		"  %l%c ",
		"%P",
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
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWritePost" }, {
	group = statusline_group,
	callback = refresh_statusline,
})

-- 将模块设置为全局变量，确保状态栏可以访问
_G.Statusline = M

return M
