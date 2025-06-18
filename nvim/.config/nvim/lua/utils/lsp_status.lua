local M = {}

local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local lsp_status_msg = ""
local is_lsp_loading = false
local redraw_scheduled = false

local function update_spinner()
	spinner_index = (spinner_index % #spinner_frames) + 1
end

local function schedule_redraw()
	if redraw_scheduled then
		return
	end

	redraw_scheduled = true
	vim.schedule(function()
		vim.cmd("redrawstatus")
		redraw_scheduled = false
	end)
end

-- 获取当前状态文本（供 statusline 使用）
function M.status()
	if lsp_status_msg == "" then
		return ""
	end

	local spinner = spinner_frames[spinner_index]
	local max_len = 40 -- 最长保留的 LSP 消息长度

	local msg = lsp_status_msg
	if #msg > max_len then
		msg = msg:sub(1, max_len - 3) .. "..."
	end

	return spinner .. " " .. msg
end

-- 处理 LSP 进度
vim.api.nvim_create_autocmd("LspProgress", {
	callback = function(args)
		local val = args.data.params.value
		local kind = val.kind or ""
		local token = val.token or ""
		local title = val.title or ""
		local message = val.message or ""

		-- 过滤掉不需要显示的通知
		if token == "rustAnalyzer/cargoWatcher" then
			return
		end

		local msg = title
		if message ~= "" then
			msg = msg .. ": " .. message
		end

		if kind == "begin" or kind == "report" then
			lsp_status_msg = msg
			is_lsp_loading = true
		elseif kind == "end" then
			lsp_status_msg = ""
			is_lsp_loading = false
		end

		schedule_redraw()
	end,
})

-- 定时更新 spinner 动画
local spinner_timer = vim.loop.new_timer()
spinner_timer:start(
	0,
	120,
	vim.schedule_wrap(function()
		update_spinner()
		if lsp_status_msg ~= "" then
			schedule_redraw()
		end
	end)
)

-- 返回是否正在加载LSP
function M.is_loading()
	return is_lsp_loading
end

return M
