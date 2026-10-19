-- 导航逻辑：错误行跳转（支持 . 重复）+ 智能关窗（按 filetype/buftype 选策略）
local M = {}

-- ============================
-- 错误行跳转
-- ============================

-- 匹配错误位置的正则
M.error_patterns = {
	"^%s*error%[[^%]]+%]:", -- Rust: error[E0425]:
	"^%s*error  TS%d+:", -- TypeScript/JavaScript
	"^%s*# ", -- Go
	"^%s*.*: error:",
	"^%s*warning:",
	"^%s*error:",
	"^%s*ERROR:",
	"^%s*panic",
	"FAILED",
	"failures:",
}

--- 当前 buffer 中所有错误行号（升序）
---@param bufnr? integer
---@return integer[]
function M.get_error_lines(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local error_lines = {}

	for line_num, line in ipairs(lines) do
		for _, pattern in ipairs(M.error_patterns) do
			if line:find(pattern) then
				table.insert(error_lines, line_num)
				break
			end
		end
	end

	return error_lines
end

local function jump_to(line)
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	vim.cmd([[normal! zv]]) -- 展开折叠
end

function M.next_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	local target
	for _, line_num in ipairs(error_lines) do
		if line_num > current_line then
			target = line_num
			break
		end
	end
	jump_to(target or error_lines[1])
end

function M.prev_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	local target
	for i = #error_lines, 1, -1 do
		if error_lines[i] < current_line then
			target = error_lines[i]
			break
		end
	end
	jump_to(target or error_lines[#error_lines])
end

-- . 重复：借 g@ 让 Neovim 记住一次操作，按 . 时重跑 operatorfunc
local last_jump_direction = nil -- "next" | "prev"

function M._repeat_jump_callback()
	if last_jump_direction == "next" then
		M.next_error()
	elseif last_jump_direction == "prev" then
		M.prev_error()
	end
end

local function repeatable(direction)
	last_jump_direction = direction
	vim.o.operatorfunc = "v:lua.require'core.navigation'._repeat_jump_callback"
	vim.api.nvim_feedkeys("g@l", "i", false)
end

function M.next_error_repeatable()
	repeatable("next")
end

function M.prev_error_repeatable()
	repeatable("prev")
end

-- ============================
-- 智能关窗
-- ============================

local closed_windows = {}

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

local function safe_win_close(win, opts)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, opts or { force = true, noautocmd = true })
	end
end

local function safe_buf_delete(buf, opts)
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, opts or { force = false })
	end
end

--- 智能关闭窗口：先按 close_map 匹配策略，匹配不到走 fallback
---@param target_win? integer 目标窗口，默认当前窗口
---@param close_map? table filetype/buftype -> { cmd }
function M.smart_close(target_win, close_map)
	local win = target_win or vim.api.nvim_get_current_win()

	if closed_windows[win] or not vim.api.nvim_win_is_valid(win) then
		closed_windows[win] = true
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local name = vim.fn.bufname(buf)

	close_map = close_map or {}
	local strategy
	if name:match("dap%-repl") then
		strategy = close_map["dap-repl"]
	end
	strategy = strategy or close_map[ft] or close_map[bt]

	closed_windows[win] = true

	if strategy then
		if type(strategy.cmd) == "function" then
			strategy.cmd()
		else
			pcall(vim.cmd, strategy.cmd)
		end
		return
	end

	-- fallback
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		safe_win_close(win, { force = false, noautocmd = true })
		return
	end

	if vim.fn.winnr("$") > 1 then
		safe_win_close(win)
		return
	end

	-- 只剩一个窗口：切到别的 buffer 再删当前
	for _, other_buf in ipairs(vim.api.nvim_list_bufs()) do
		if other_buf ~= buf and vim.api.nvim_buf_is_loaded(other_buf) then
			vim.api.nvim_win_set_buf(win, other_buf)
			safe_buf_delete(buf)
			return
		end
	end

	if vim.fn.confirm("这是最后一个窗口，确认退出 Neovim？", "&是\n&否", 2) == 1 then
		vim.cmd("qa")
	end
end

return M
