local utils = require("utils.utils")
local colors, icons = utils.palette, utils.icons
local lsp_status = require("utils.lsp_status")

-- 定义高亮组
local function set_highlights(highlight_defs)
	for group, opts in pairs(highlight_defs) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end
set_highlights({
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
})

Statusline = {}

-- -------------------- 模式定义 --------------------
Statusline.modes = {
	["n"] = { label = "NORMAL", hl = "NormalMode" },
	["i"] = { label = "INSERT", hl = "InsertMode" },
	["v"] = { label = "VISUAL", hl = "VisualMode" },
	["V"] = { label = "V-LINE", hl = "VisualMode" },
	[""] = { label = "V-BLOCK", hl = "VisualMode" },
	["R"] = { label = "REPLACE", hl = "ReplaceMode" },
	["c"] = { label = "COMMAND", hl = "DefaultMode" },
	["t"] = { label = "TERMINL", hl = "DefaultMode" },
}

-- 获取当前模式并应用颜色高亮
function Statusline.mode()
	local current_mode = vim.api.nvim_get_mode().mode
	local mode_info = Statusline.modes[current_mode] or { label = current_mode, hl = "DefaultMode" }
	return "%#StatuslineIcon# %*" .. "%#" .. mode_info.hl .. "#" .. mode_info.label .. "%*"
end

-- -- -------------------- 文件名和图标 --------------------
-- function Statusline.get_filename_with_icon()
-- 	local filename = vim.fn.expand("%:t") -- 获取当前文件名
-- 	local file_extension = vim.fn.expand("%:e") -- 获取文件扩展名
-- 	local icon, _ = require("nvim-web-devicons").get_icon(filename, file_extension, { default = true })
-- 	return icon and icon .. " " .. filename or filename
-- end

-- -------------------- LSP 状态 --------------------
function Statusline.lsp_diagnostics()
	if lsp_status.is_loading() then
		return "" -- 如果LSP正在加载，返回空字符串
	end

	local count = vim.diagnostic.get(0)
	local parts = {}
	local icon = icons.diagnostic
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
			local highlight_group = "Diagnostic" .. key
			table.insert(parts, "%#" .. highlight_group .. "#" .. icon[key] .. "%*" .. "<" .. num .. ">")
		end
	end
	return table.concat(parts, " ")
end

-- 获取当前 buffer 附加的 LSP 客户端名称
function Statusline.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
	if vim.tbl_isempty(buf_clients) then
		return ""
	end
	-- 给每个客户端加上编号
	local client_names = {}
	for idx, client in ipairs(buf_clients) do
		table.insert(client_names, string.format("%d.%s", idx, client.name))
	end
	-- 拼接客户端名称，并返回
	return "%#LspIcon#" .. "󰂵 " .. "%*" .. table.concat(client_names, " ") .. " 󱞩"
end

-- LSP 状态（包含客户端名称、诊断和进度信息）
function Statusline.lsp()
	return table.concat({
		Statusline.lsp_clients(),
		" " .. require("utils.lsp_status").status(),
		Statusline.lsp_diagnostics(),
	})
end

-- -------------------- USB 连接状态（嵌入式设备） --------------------
function Statusline.usb()
	return require("utils.usb_status").UsbStatus()
end

-- -------------------- 芯片状态（嵌入式设备） --------------------
local chip_config = require("utils.cross_config")
-- 定义状态栏显示函数
function Statusline.chip()
	return chip_config.ChipStatus() -- 调用 ChipStatus 函数
end

-- -------------------- 调试状态 --------------------
function Statusline.dap_status()
	local dap_status = require("dap").status()
	if dap_status == "" then
		return "" -- 如果没有调试会话，返回空字符串
	end
	return "%#DapIcon#" .. " " .. "%*" .. dap_status -- 有调试会话时，返回图标和状态
end

-- -------------------- Git 状态 --------------------
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return "%#GitIcon#" .. " " .. "%*" .. "[ ]"
	end
	local parts = { "%#GitIcon#" .. " " .. "%*" .. "[" .. git_info.head .. "]" }
	for key, icon in pairs({
		added = "%#GitIconAdded#" .. "+" .. "%*",
		removed = "%#GitIconRemoved#" .. "-" .. "%*",
		changed = "%#GitIconChanged#" .. "󰱑" .. "%*",
	}) do
		if git_info[key] and git_info[key] > 0 then
			table.insert(parts, icon .. git_info[key])
		end
	end
	return " " .. table.concat(parts, " ") .. " "
end

-- -------------------- 动态滚动条 --------------------
function Statusline.get_scrollbar()
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
	local total_lines, cur_line = vim.api.nvim_buf_line_count(0), vim.api.nvim_win_get_cursor(0)[1]
	if total_lines <= 1 then
		return "%#PinkHighlight#" .. progress_icons[#progress_icons] .. "%*" -- 只有一行时，显示满格图标
	end
	local progress = (cur_line - 1) / (total_lines - 1)
	local icon_index = math.ceil(progress * (#progress_icons - 1)) + 1
	return "%#PinkHighlight#" .. progress_icons[icon_index] .. "%*"
end

-- -------------------- 状态栏内容 --------------------
function Statusline.active()
	return table.concat({
		"%#Normal#", -- 默认文本高亮组
		string.format("%-46s", Statusline.mode()), -- 左对齐，13个字符
		-- " " .. Statusline.get_filename_with_icon() .. "  ", -- 动态获取文件图标
		Statusline.vcs() .. "  ", -- Git 状态
		Statusline.lsp(), -- LSP 状态
		"%=", -- 分隔符
		Statusline.dap_status() .. " ", -- dap调试信息
		Statusline.chip() .. "  ",
		Statusline.usb() .. " ",
		"  %l%c ", -- 行列号
		"%P", -- 文件百分比
		Statusline.get_scrollbar(), -- 动态图标
	})
end

-- -------------------- 自动更新状态栏 --------------------
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

return Statusline
