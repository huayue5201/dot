-- 设置粗体高亮组
vim.cmd("highlight Bold gui=bold")

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
	-- 使用粗体的高亮组
	return "%#Bold#" .. "  " .. (Statusline.modes[current_mode] or " ")
end

-- Git 状态
function Statusline.vcs()
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or not git_info.head then
		return ""
	end
	local parts = { " " .. git_info.head }
	-- 显示修改状态的图标
	for key, icon in pairs({
		added = "",
		changed = "",
		removed = "",
	}) do
		if git_info[key] and git_info[key] > 0 then
			table.insert(parts, icon .. " " .. git_info[key])
		end
	end
	return " " .. table.concat(parts, " ") .. " "
end

-- 获取 LSP 诊断信息
function Statusline.lsp_diagnostics()
	local count = vim.diagnostic.get(0)
	local parts = {}
	for severity, icon in pairs({
		[vim.diagnostic.severity.ERROR] = "✘",
		[vim.diagnostic.severity.WARN] = "▲",
		[vim.diagnostic.severity.HINT] = "⚑",
		[vim.diagnostic.severity.INFO] = "»",
	}) do
		local num = #vim.tbl_filter(function(d)
			return d.severity == severity
		end, count)
		if num > 0 then
			table.insert(parts, icon .. " " .. num)
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
	progress = #progress > 32 and string.sub(progress, 1, 32) .. "…" or progress
	return " " .. spinner .. " " .. progress
end

-- 获取当前 buffer 附加的 LSP 客户端名称
function Statusline.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
	if vim.tbl_isempty(buf_clients) then
		return ""
	end
	return "  "
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

-- 创建状态栏内容
function Statusline.active()
	return table.concat({
		"%#Normal#", -- 默认文本高亮组
		string.format("%-19s", Statusline.mode()), -- 左对齐，13个字符
		"  " .. "%t  ", -- 文件名
		Statusline.lsp(), -- LSP 状态
		"%=", -- 分隔符
		Statusline.vcs(), -- Git 状态
		" %l/%c", -- 行列号
		" %p%%", -- 文件百分比
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
