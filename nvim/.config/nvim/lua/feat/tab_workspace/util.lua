-- tab_workspace 的共享判定：什么样的 buffer / 窗口属于「工作区」。
local M = {}

-- 侧栏/抽屉类面板：自己管理开关与显示，不该跟着 tab 归属走（否则切 tab 时
-- 面板会凭空出现或消失）。它们的 buftype 不一定是 nofile，所以再按 filetype 兜一层。
local EXCLUDED_FILETYPES = {
	["neo-tree"] = true,
	["neo-tree-popup"] = true,
	["sqmeow-drawer"] = true,
	["todo2drawer"] = true,
	fugitive = true,
	fugitiveblame = true,
	oil = true,
	["mini.files"] = true,
}

-- 编辑器自己管理的特殊 buffer（help / quickfix / prompt / nofile / acwrite），
-- 以及插件内部的临时 buffer。
-- terminal 故意不在这里：终端天然属于某个 tab，必须跟着归属走，
-- 否则在一个 tab 开的终端会串到所有 tab 的 bufferline 里。
local SPECIAL_BUFTYPES = {
	nofile = true,
	quickfix = true,
	help = true,
	prompt = true,
	acwrite = true,
	nowrite = true,
}

--- 是否由工作区管理（记录归属、由 relist 维护 buflisted）
---@param bufnr integer
---@return boolean
function M.is_managed_buf(bufnr)
	if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local bo = vim.bo[bufnr]
	if SPECIAL_BUFTYPES[bo.buftype] then
		return false
	end
	if EXCLUDED_FILETYPES[bo.filetype] then
		return false
	end
	return true
end

--- 是否会被写进会话：受管理、有名字（无名字的 [No Name] 无从恢复），
--- 且不是终端（终端 buffer 也有名字，但进程没法存盘，恢复出来是死 buffer）
---@param bufnr integer
---@return boolean
function M.is_saved_buf(bufnr)
	if not M.is_managed_buf(bufnr) or vim.bo[bufnr].buftype ~= "" then
		return false
	end
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return false
	end
	-- 只看 buftype 不够：被 bufadd("term://...") 造出来的僵尸 buffer buftype 是 ""
	-- （进程已经没了），存进会话后 resession 载入时会 bufload 它 —— 而 bufload 一个
	-- term:// 名字会真的把 shell 拉起来，表现就是「加载会话时凭空冒出一个终端」。
	if name:find("^term://") then
		return false
	end
	-- 注意：不要用 vim.bo[bufnr].channel 判断（普通 buffer 里它返回 0，Lua 里 0 是真值，
	-- 会把所有 buffer 都判成终端）。只认 terminal_job_id。
	if vim.b[bufnr].terminal_job_id then
		return false
	end
	return true
end

--- 是否浮窗（relative ~= ""）：浮窗里显示的 buffer 不参与归属，
--- 否则「在浮窗里可见」的真实文件 buffer 会被 listed 而泄漏到 bufferline。
---@param win integer|nil
---@return boolean
function M.is_float_win(win)
	if not win or win == 0 or not vim.api.nvim_win_is_valid(win) then
		return false
	end
	return vim.api.nvim_win_get_config(win).relative ~= ""
end

--- 是否特殊窗口（侧栏 / quickfix / 预览等）。
--- 这些窗口不参与归属：面板 buffer 由面板自己管，quickfix 窗口里显示的
--- 真实文件 buffer 也不该因为「被 :copen 预览过」就变成当前 tab 的。
---@param win integer|nil
---@return boolean
function M.is_panel_win(win)
	if not win or win == 0 or not vim.api.nvim_win_is_valid(win) then
		return false
	end
	local ok, kind = pcall(vim.fn.win_gettype, win)
	if not ok then
		return false
	end
	-- autocmd 期间 win_gettype() 会返回 "autocmd"，那不是面板
	return kind ~= "" and kind ~= "autocmd"
end

--- 是否「不是真正在编辑文件」的窗口（浮窗或特殊窗口）
---@param win integer|nil
---@return boolean
function M.is_ephemeral_win(win)
	return M.is_float_win(win) or M.is_panel_win(win)
end

--- 是否正在加载会话（resession 或 mksession/`:restart` 的 SessionLoad）。
--- 加载期间不要 relist / 抢归属 / 删 buffer。
---@return boolean
function M.resession_loading()
	-- `:restart` 用 mksession 生成临时会话后 source，脚本开头 `let SessionLoad = 1`
	if vim.g.SessionLoad == 1 then
		return true
	end
	local ok, resession = pcall(require, "resession")
	return ok and resession.is_loading()
end

return M
