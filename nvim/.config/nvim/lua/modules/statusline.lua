-- lua/modules/statusline.lua
-- 定义模式指示器
local modes = {
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

local function mode()
	local current_mode = vim.api.nvim_get_mode().mode
	return string.format(" %s ", modes[current_mode]):upper()
end

-- 创建状态栏
function my_statusline()
	return table.concat({
		"%#Statusline#", -- 设置状态栏颜色
		mode(), -- 显示模式
		" %f", -- 显示文件名
		"%=", -- 使用最大宽度
		" %l:%c", -- 当前行号和列号
		" %p%%", -- 文件百分比
		"%#Normal#", -- 恢复正常文本颜色
	})
end

-- 显示状态栏
vim.cmd([[
    augroup Statusline
    au!
    au WinEnter,BufEnter * setlocal statusline=%!v:lua.my_statusline()
    augroup END
]])
