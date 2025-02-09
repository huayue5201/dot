-- lua/util/statusline.lua

Statusline = {}

-- 定义模式指示器
Statusline.modes = {
	["n"] = "NORMAL",
	["no"] = "NORMAL",
	["v"] = "VISUAL",
	["V"] = "V-LINE",
	[""] = "V-BLOCK",
	["s"] = "SELECT",
	["S"] = "S-LINE",
	[""] = "S-BLOCK",
	["i"] = "INSERT",
	["ic"] = "INSERT",
	["R"] = "REPLACE",
	["Rv"] = "V-REPLACE",
	["c"] = "COMMAND",
	["t"] = "TERMINAL",
}

-- 获取当前模式
function Statusline.mode()
	local current_mode = vim.api.nvim_get_mode().mode
	return Statusline.modes[current_mode] and string.format(" %s ", Statusline.modes[current_mode]) or ""
end

-- Git 状态
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return ""
	end
	local parts = {}
	if git_info.added and git_info.added > 0 then
		table.insert(parts, (" " .. git_info.added))
	end
	if git_info.changed and git_info.changed > 0 then
		table.insert(parts, (" " .. git_info.changed))
	end
	if git_info.removed and git_info.removed > 0 then
		table.insert(parts, (" " .. git_info.removed))
	end
	table.insert(parts, (" " .. git_info.head))
	return " " .. table.concat(parts, " ") .. " "
end

-- 获取 LSP 诊断信息
function Statusline.lsp_diagnostics()
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

-- LSP 进度动画（不做屏幕宽度判断，直接显示）
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1

function Statusline.lsp_progress()
	local progress = vim.lsp.status() or ""
	if progress == "" then
		return ""
	end

	-- 获取当前 spinner 帧，并更新下标
	local spinner = spinner_frames[spinner_index]
	spinner_index = (spinner_index % #spinner_frames) + 1

	-- 截断进度信息，避免过长
	local max_len = 30
	if #progress > max_len then
		progress = string.sub(progress, 1, max_len) .. "…"
	end

	return string.format(" %s %s", spinner, progress)
end

-- LSP 状态（包含诊断和进度信息）
function Statusline.lsp()
	local lsp_diagnostics = Statusline.lsp_diagnostics()
	local lsp_progress = Statusline.lsp_progress()
	-- 显示 LSP 客户端信息也可以加入，不过这里仅显示诊断和进度
	return lsp_diagnostics .. " " .. lsp_progress
end

-- 创建状态栏内容
function Statusline.active()
	local mode_str = Statusline.mode()
	local git_str = Statusline.vcs()
	local file_name = " %f"
	local lsp_str = Statusline.lsp()
	local line_col = " %l:%c"
	local file_percent = " %p%%"

	return table.concat({
		"%#Normal#", -- 默认文本高亮组
		mode_str, -- 模式
		git_str, -- Git 状态
		file_name, -- 文件名
		"%=", -- 自动分隔（左右对齐）
		lsp_str, -- LSP 诊断及进度
		"%=", -- 自动分隔
		line_col, -- 行列号
		file_percent, -- 文件百分比
	})
end

-- 启动一个定时器，每 100 毫秒刷新一次状态栏，确保 spinner 能更新
if not Statusline._spinner_timer then
	Statusline._spinner_timer = vim.loop.new_timer()
	Statusline._spinner_timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			-- 重绘 statusline
			vim.cmd("redrawstatus")
		end)
	)
end

-- 设置状态栏：在窗口进入、缓冲区进入时更新
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("Statusline", { clear = true }),
	callback = function()
		local win_id = vim.api.nvim_get_current_win()
		vim.api.nvim_set_option_value("statusline", "%!v:lua.Statusline.active()", { win = win_id })
	end,
})
