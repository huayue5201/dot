-- lua/modules/statusline.lua

Statusline = {}

-- 定义模式指示器
Statusline.modes = {
	["n"] = "NORMAL",
	["no"] = "NORMAL",
	["v"] = "VISUAL",
	["V"] = "VISUAL LINE",
	[""] = "VISUAL BLOCK",
	["s"] = "SELECT",
	["S"] = "SELECT LINE",
	[""] = "SELECT BLOCK",
	["i"] = "INSERT",
	["ic"] = "INSERT",
	["R"] = "REPLACE",
	["Rv"] = "VISUAL REPLACE",
	["c"] = "COMMAND",
	["cv"] = "VIM EX",
	["ce"] = "EX",
	["r"] = "PROMPT",
	["rm"] = "MOAR",
	["r?"] = "CONFIRM",
	["!"] = "SHELL",
	["t"] = "TERMINAL",
}

-- 获取当前模式
function Statusline.mode()
	local current_mode = vim.api.nvim_get_mode().mode
	return Statusline.modes[current_mode] and string.format(" %s ", Statusline.modes[current_mode]):upper() or ""
end

-- Git 仓库状态
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return " Git: N/A "
	end
	local parts = {}
	if git_info.added and git_info.added > 0 then
		table.insert(parts, ("%#GitSignsAdd#+" .. git_info.added))
	end
	if git_info.changed and git_info.changed > 0 then
		table.insert(parts, ("%#GitSignsChange#~" .. git_info.changed))
	end
	if git_info.removed and git_info.removed > 0 then
		table.insert(parts, ("%#GitSignsDelete#-" .. git_info.removed))
	end
	table.insert(parts, ("%#GitSignsAdd# " .. git_info.head .. " %#Normal#"))
	return " " .. table.concat(parts, " ") .. " "
end

-- 创建状态栏内容
-- 创建状态栏内容
function Statusline.active()
	local mode_str = Statusline.mode()
	local git_str = Statusline.vcs() -- 添加 Git 仓库状态
	local file_name = " %f"
	local line_col = " %l:%c"
	local file_percent = " %p%%"

	return table.concat({
		"%#Normal#", -- 设置为默认文本颜色
		mode_str, -- 显示模式
		git_str, -- 显示 Git 仓库状态
		file_name, -- 显示文件名
		"%=", -- 使用最大宽度
		line_col, -- 当前行号和列号
		file_percent, -- 文件百分比
	})
end

-- 非活动状态的状态栏内容
function Statusline.inactive()
	return "%F"
end

-- 短状态栏内容
function Statusline.short()
	return "%#StatusLineNC#   NvimTree"
end

-- 显示状态栏
vim.cmd([[
    augroup Statusline
    au!
    au WinEnter,BufEnter * setlocal statusline=%!v:lua.Statusline.active()
    augroup END
]])
