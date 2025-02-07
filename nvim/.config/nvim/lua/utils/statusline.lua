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
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return "  No Git "
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

-- 获取 LSP 客户端信息
function Statusline.get_lsp_clients()
	local attached_clients = vim.lsp.get_clients({ bufnr = 0 })
	if #attached_clients == 0 then
		return "No LSP"
	end
	local names = {}
	for _, client in ipairs(attached_clients) do
		local name = client.name:gsub("language.server", "ls")
		table.insert(names, name)
	end
	return "[" .. table.concat(names, ", ") .. "]"
end
-- 获取 LSP 诊断信息
function Statusline.get_lsp_diagnostics()
	local count = {
		errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }),
		warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }),
		hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT }),
		info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO }),
	}
	local parts = {}
	if count.errors > 0 then
		table.insert(parts, "✘ " .. count.errors)
	end
	if count.warnings > 0 then
		table.insert(parts, "▲ " .. count.warnings)
	end
	if count.hints > 0 then
		table.insert(parts, "⚑ " .. count.hints)
	end
	if count.info > 0 then
		table.insert(parts, "» " .. count.info)
	end
	return table.concat(parts, " ")
end
-- 获取 LSP 状态（客户端和诊断信息）
function Statusline.lsp()
	local lsp_clients = Statusline.get_lsp_clients()
	local lsp_diagnostics = Statusline.get_lsp_diagnostics()
	return lsp_clients .. " " .. lsp_diagnostics
end

-- 创建状态栏内容
function Statusline.active()
	local mode_str = Statusline.mode()
	local git_str = Statusline.vcs() -- Git 状态
	local file_name = " %f"
	local lsp_str = Statusline.lsp() -- LSP 状态
	local line_col = " %l:%c"
	local file_percent = " %p%%"

	return table.concat({
		"%#Normal#", -- 设置为默认文本颜色
		mode_str, -- 显示模式
		git_str, -- Git 状态
		file_name, -- 文件名
		"%=", -- 最大宽度
		lsp_str, -- LSP 状态
		"%=", -- 最大宽度
		line_col, -- 行列号
		file_percent, -- 文件百分比
	})
end

-- 显示状态栏
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("Statusline", { clear = true }),
	callback = function()
		local win_id = vim.api.nvim_get_current_win()
		-- 设置窗口的 statusline 选项
		vim.api.nvim_set_option_value("statusline", "%!v:lua.Statusline.active()", { win = win_id })
	end,
})
