local utils = require("config.utils")

-- 定义高亮组
vim.cmd("highlight DefaultMode gui=bold")
vim.cmd("highlight NormalMode gui=bold")
vim.cmd("highlight InsertMode gui=bold")
vim.cmd("highlight VisualMode gui=bold")
vim.cmd("highlight ReplaceMode gui=bold")
vim.cmd("highlight PinkHighlight guifg=#FFD700 gui=bold")

Statusline = {}

-- 定义模式映射
Statusline.modes = {
	["n"] = { label = "NORMAL", hl = "NormalMode" },
	["i"] = { label = "INSERT", hl = "InsertMode" },
	["v"] = { label = "VISUAL", hl = "VisualMode" },
	["V"] = { label = "V-LINE", hl = "VisualMode" },
	[""] = { label = "V-BLOCK", hl = "VisualMode" },
	["R"] = { label = "REPLACE", hl = "ReplaceMode" },
	["c"] = { label = "COMMAND", hl = "DefaultMode" },
	["t"] = { label = "TERMINAL", hl = "DefaultMode" },
}

-- 获取当前模式并应用颜色高亮
function Statusline.mode()
	local current_mode = vim.api.nvim_get_mode().mode
	local mode_info = Statusline.modes[current_mode] or { label = current_mode, hl = "DefaultMode" }
	return "%#" .. mode_info.hl .. "#" .. "  " .. mode_info.label .. "%*"
end

-- Git 状态
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return ""
	end
	local parts = { " " .. git_info.head }
	for key, icon in pairs({
		added = "+",
		changed = "󰱑",
		removed = "-",
	}) do
		if git_info[key] and git_info[key] > 0 then
			table.insert(parts, icon .. git_info[key])
		end
	end
	return " " .. table.concat(parts, " ") .. " "
end

-- 获取 LSP 诊断信息
function Statusline.lsp_diagnostics()
	local count = vim.diagnostic.get(0)
	local parts = {}
	local severity_map = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.HINT] = "HINT",
		[vim.diagnostic.severity.INFO] = "INFO",
	}
	for severity, key in pairs(severity_map) do
		local num = #vim.tbl_filter(function(d)
			return d.severity == severity
		end, count)
		if num > 0 then
			table.insert(parts, utils.diagnostic_icons[key] .. " " .. num)
		end
	end
	return table.concat(parts, " ")
end

-- LSP 进度动画
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
function Statusline.lsp_progress()
	local progress = vim.lsp.status() or ""
	if progress == "" then
		return ""
	end
	local spinner = spinner_frames[spinner_index]
	spinner_index = (spinner_index % #spinner_frames) + 1
	progress = #progress > 40 and string.sub(progress, 1, 40) .. "…" or progress
	return " " .. spinner .. " " .. progress
end

-- 获取当前 buffer 附加的 LSP 客户端名称
function Statusline.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
	if vim.tbl_isempty(buf_clients) then
		return ""
	end
	return "󰂵 " -- 
		.. table.concat(
			vim.tbl_map(function(client)
				return client.name
			end, buf_clients),
			", "
		)
		.. " 󱞩 "
end

-- LSP 状态（包含客户端名称、诊断和进度信息）
function Statusline.lsp()
	return table.concat({
		Statusline.lsp_clients(),
		Statusline.lsp_diagnostics(),
		" " .. Statusline.lsp_progress(),
	}, " ")
end

-- 动态图标
local function get_scrollbar()
	local progress_icons = {
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
	-- local progress_icons = { " ", "󰪞 ", "󰪟 ", "󰪠 ", "󰪡 ", "󰪢 ", "󰪣 ", "󰪤 ", "󰪥 " }
	-- local progress_icons = { "󰋙 ", "󰫃 ", "󰫄 ", "󰫅 ", "󰫆 ", "󰫇 " }
	local total_lines, cur_line = vim.api.nvim_buf_line_count(0), vim.api.nvim_win_get_cursor(0)[1]
	if total_lines <= 1 then
		return "%#PinkHighlight#" .. progress_icons[#progress_icons] .. "%*" -- 只有一行时，显示满格图标
	end
	local progress = (cur_line - 1) / (total_lines - 1)
	local icon_index = math.ceil(progress * (#progress_icons - 1)) + 1
	return "%#PinkHighlight#" .. progress_icons[icon_index] .. "%*"
end

-- 创建状态栏内容
function Statusline.active()
	-- 获取文件图标

	return table.concat({
		"%#Normal#", -- 默认文本高亮组
		string.format("%-28s", Statusline.mode()) .. "", -- 左对齐，13个字符
		"  " .. "%t  ", -- 文件名
		Statusline.lsp(), -- LSP 状态
		"%=", -- 分隔符
		-- 由akinsho/toggleterm.nvim提供
		'%{&ft == "toggleterm" ? "terminal (".b:toggle_number.")" : ""}',
		Statusline.vcs(), -- Git 状态
		" 󰴍 %l%c ", -- 行列号
		"  %P", -- 文件百分比
		get_scrollbar(),
	})
end

-- 设置状态栏：在窗口进入、缓冲区进入时更新
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("Statusline", { clear = true }),
	callback = function()
		vim.api.nvim_set_option_value(
			"statusline",
			"%!v:lua.Statusline.active()",
			{ win = vim.api.nvim_get_current_win() }
		)
	end,
})

-- LSP 进度更新的定时器处理
local timer = vim.loop.new_timer()
vim.api.nvim_create_autocmd("LspProgress", {
	group = vim.api.nvim_create_augroup("LSPProgress", { clear = true }),
	callback = function()
		vim.cmd.redrawstatus()
		timer:stop() -- 停止之前的定时器
		timer:start(150, 0, vim.schedule_wrap(vim.cmd.redrawstatus)) -- 延迟执行重绘
	end,
})
