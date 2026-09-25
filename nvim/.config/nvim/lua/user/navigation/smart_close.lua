-- 智能关闭窗口：按 filetype/buftype 匹配关闭策略，无策略时走 fallback 逻辑
local M = {}

local buf_keymaps = require("user.navigation.keymaps")

-- 记录已关闭的窗口，防止重复关闭
local closed_windows = {}

-- 窗口关闭后清理标记，避免窗口 ID 复用导致误判
vim.api.nvim_create_autocmd("WinClosed", {
	group = vim.api.nvim_create_augroup("NavSmartCloseCleanup", { clear = true }),
	desc = "清理 smart_close 的窗口标记",
	callback = function()
		for win in pairs(closed_windows) do
			if not vim.api.nvim_win_is_valid(win) then
				closed_windows[win] = nil
			end
		end
	end,
})

-- 安全关闭窗口（带有效性检查）
local function safe_win_close(win, opts)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, opts or { force = true, noautocmd = true })
	end
end

-- 安全删除缓冲区（带有效性检查）
local function safe_buf_delete(buf, opts)
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, opts or { force = false })
	end
end

-- 执行关闭策略（cmd 为 vim 命令字符串或函数）
local function exec_strategy(cmd)
	if type(cmd) == "function" then
		cmd()
	else
		pcall(vim.cmd, cmd)
	end
end

-- 智能关闭当前或指定窗口
---@param target_win? integer 目标窗口 ID，默认当前窗口
function M.smart_close(target_win)
	local win = target_win or vim.api.nvim_get_current_win()

	if closed_windows[win] then
		return
	end
	if not vim.api.nvim_win_is_valid(win) then
		closed_windows[win] = true
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local name = vim.fn.bufname(buf)

	-- 查找关闭策略
	local close_map = buf_keymaps["q"]
	local strategy = nil

	-- dap-repl 特殊匹配（根据缓冲区名称）
	if name:match("dap%-repl") then
		strategy = close_map["dap-repl"]
	end

	-- 按 filetype 或 buftype 匹配策略
	strategy = strategy or close_map[ft] or close_map[bt]

	-- 标记窗口已关闭
	closed_windows[win] = true

	if strategy then
		exec_strategy(strategy.cmd)
		return
	end

	-- ============================
	-- fallback：智能关闭逻辑
	-- ============================

	local cfg = vim.api.nvim_win_get_config(win)

	-- 浮动窗口：直接关闭
	if cfg.relative ~= "" then
		safe_win_close(win, { force = false, noautocmd = true })
		return
	end

	-- 多窗口：直接关闭当前窗口
	if vim.fn.winnr("$") > 1 then
		safe_win_close(win)
		return
	end

	-- 只有一个窗口：尝试切换到其他缓冲区
	local buffers = vim.api.nvim_list_bufs()
	if #buffers > 1 then
		for _, other_buf in ipairs(buffers) do
			if other_buf ~= buf and vim.api.nvim_buf_is_loaded(other_buf) then
				vim.api.nvim_win_set_buf(win, other_buf)
				safe_buf_delete(buf)
				return
			end
		end
	end

	-- 最后一个缓冲区：询问是否退出 Neovim
	local choice = vim.fn.confirm("这是最后一个窗口，确认退出 Neovim？", "&是\n&否", 2)
	if choice == 1 then
		vim.cmd("qa")
	end
end

return M
