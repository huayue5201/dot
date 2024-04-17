-- lua/util/statusline.lua

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
-- 依赖lewis6991/gitsigns.nvim插件
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return "  N/A "
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

-- LSP状态
function Statusline.lsp()
	local count = {
		errors = vim.tbl_count(vim.diagnostic.get(0, { severity = "Error" })),
		warnings = vim.tbl_count(vim.diagnostic.get(0, { severity = "Warn" })),
		hints = vim.tbl_count(vim.diagnostic.get(0, { severity = "Hint" })),
		info = vim.tbl_count(vim.diagnostic.get(0, { severity = "Info" })),
	}
	local parts = {}
	if count["errors"] > 0 then
		table.insert(parts, " 󰅚  " .. count["errors"])
	end
	if count["warnings"] > 0 then
		table.insert(parts, " 󰀪 " .. count["warnings"])
	end
	if count["hints"] > 0 then
		table.insert(parts, " 󰌶 " .. count["hints"])
	end
	if count["info"] > 0 then
		table.insert(parts, "   " .. count["info"])
	end
	return table.concat(parts, "")
end

-- 创建状态栏内容
function Statusline.active()
	local mode_str = Statusline.mode()
	local git_str = Statusline.vcs() -- 添加 Git 仓库状态
	local file_name = " %f"
	local lsp_str = Statusline.lsp() -- 添加 LSP 状态
	local line_col = " %l:%c"
	local file_percent = " %p%%"

	return table.concat({
		"%#Normal#", -- 设置为默认文本颜色
		-- "%#Statusline#",
		mode_str, -- 显示模式
		git_str, -- 显示 Git 仓库状态
		file_name, -- 显示文件名
		"%=", -- 使用最大宽度
		lsp_str,
		"%=", -- 使用最大宽度
		line_col, -- 当前行号和列号
		file_percent, -- 文件百分比
	})
end

-- 显示状态栏
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("Statusline", { clear = true }),
	callback = function()
		local bufnr = vim.fn.bufnr("%")
		-- 设置缓冲区的 statusline 选项
		vim.api.nvim_buf_set_option(bufnr, "statusline", "%!v:lua.Statusline.active()")
	end,
})
