-- tab_workspace 的共享判定工具。
local M = {}

--- 是否为受工作区管理的普通 buffer。
---@param bufnr integer
---@return boolean
function M.is_workspace_buf(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end
	-- 无名 scratch buffer 也算工作区 buffer：否则 :enew 出来的 [No Name]
	-- 会一直 listed，泄漏到所有 tab 的 bufferline 里。导出会话时仍会跳过空 name。
	if vim.bo[bufnr].filetype == "neo-tree" then
		return false
	end
	return true
end

--- 是否为浮窗（relative ~= ""）。浮窗里显示的 buffer 不参与工作区归属，
--- 否则“在浮窗里可见”的真实文件 buffer 会被 listed，泄漏到 bufferline。
---@param win integer
---@return boolean
function M.is_float_win(win)
	if not win or win == 0 then
		return false
	end
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end
	return vim.api.nvim_win_get_config(win).relative ~= ""
end

--- resession 是否正在加载会话（加载期间不要 relist / 抢归属）。
---@return boolean
function M.resession_loading()
	local ok, resession = pcall(require, "resession")
	return ok and resession.is_loading()
end

return M
