-- buflisted 同步：改 buflisted 的唯一实现。
--
-- 不变量：对受管理的 buffer，`buflisted` == 「它在当前 tab 的可见集合里」。
-- 于是 bufferline、:ls、:bnext 等所有按 listed 工作的地方，看到的都是
-- 「当前工作区的 buffer」，不需要各自再过滤一遍。
local util = require("feat.tab_workspace.util")
local state = require("feat.tab_workspace.state")

local M = {}

-- 我们自己改 buflisted 期间为 true：Neovim 把 buflisted 置 false 时会抛一个伪
-- BufDelete，调用方（BufDelete autocmd）据此忽略，否则会把 buffer 从归属表里误删。
local toggling = false
local relist_scheduled = false

---@return boolean
function M.is_toggling()
	return toggling
end

--- 不进 bufferline 的 buftype：terminal（betterTerm 下部分屏终端）等
--- 说明：terminal 仍然是「受管理 buffer」（跟着 tab 归属走，buflisted 照旧），
--- 只是不在 bufferline 里占一格——它有自己的窗口/标签栏，:ls 和 :bnext 仍然可达。
local BAR_HIDDEN_BUFTYPES = {
	terminal = true,
}

--- 是否「不占 bufferline 一格」（终端等）
---@param bufnr integer
---@return boolean
function M.is_bar_hidden(bufnr)
	return BAR_HIDDEN_BUFTYPES[vim.bo[bufnr].buftype] == true
end

--- 当前 tab 应该出现在 bufferline 里的 buffer（渲染口径）
---@return integer[]
function M.visible_buffers()
	local visible = state.visible_set(vim.api.nvim_get_current_tabpage())
	local out = {}
	for bufnr in pairs(visible) do
		if util.is_managed_buf(bufnr) and not M.is_bar_hidden(bufnr) then
			out[#out + 1] = bufnr
		end
	end
	table.sort(out)
	return out
end

local function request_redraw()
	local bl = package.loaded["bufferline"]
	if type(bl) == "table" and type(bl.redraw) == "function" then
		-- 走 bufferline 自己的去重调度，避免和它的 autocmd 在同一轮里重复渲染
		bl.redraw()
		return
	end
	vim.schedule(function()
		pcall(vim.cmd, "redrawtabline")
	end)
end

--- 按当前 tab 的可见集合重设所有受管理 buffer 的 buflisted
function M.relist()
	-- 会话加载期间 buffer 还在按名字恢复，此时改 listed 会打乱 resession
	if util.resession_loading() then
		return
	end
	local visible = state.visible_set(vim.api.nvim_get_current_tabpage())

	-- 改 buflisted=false 会触发伪 BufDelete，其他插件会误判成 buffer 被删
	-- （例如 todo2 会取消待写入的防抖同步、清掉标签筛选）。
	-- 只压掉 BufDelete，保留 BufAdd，让 neo-tree 的 opened markers 在切回 tab 时仍能刷新。
	local prev_eventignore = vim.o.eventignore
	vim.o.eventignore = prev_eventignore == "" and "BufDelete" or (prev_eventignore .. ",BufDelete")
	toggling = true
	local ok, err = pcall(function()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if util.is_managed_buf(bufnr) then
				-- 终端永远 unlisted：它有自己的窗口/侧栏，不进 bufferline / :ls / :bnext
				local want = visible[bufnr] == true and not M.is_bar_hidden(bufnr)
				if vim.bo[bufnr].buflisted ~= want then
					vim.bo[bufnr].buflisted = want
				end
			end
		end
	end)
	toggling = false
	vim.o.eventignore = prev_eventignore
	if not ok then
		error(err)
	end

	request_redraw()
end

--- 下一轮事件循环里再 relist 一次（同一轮内的多次请求合并成一次）
function M.schedule_relist()
	if relist_scheduled then
		return
	end
	relist_scheduled = true
	vim.schedule(function()
		relist_scheduled = false
		pcall(M.relist)
	end)
end

return M
