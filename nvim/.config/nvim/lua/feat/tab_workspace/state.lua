-- buffer 归属表：tab -> { [bufnr] = true }，以及「最近访问的 tab」。
-- 纯状态，不改任何 vim 选项（改 buflisted 的唯一实现在 listed.lua）。
local util = require("feat.tab_workspace.util")

local M = {}

---@type table<integer, table<integer, true>>
local owned = {}
---@type integer|nil
local last_tab

--- 把 buffer 归到 tab。移动语义：一个 buffer 只属于一个 tab（最近出现的地方）。
---@param tab integer
---@param bufnr integer
---@return boolean 是否已归属
function M.claim(tab, bufnr)
	if not util.is_managed_buf(bufnr) then
		return false
	end
	if not tab or not vim.api.nvim_tabpage_is_valid(tab) then
		return false
	end
	if owned[tab] == nil then
		owned[tab] = {}
	end
	if owned[tab][bufnr] then
		return true
	end
	for other, set in pairs(owned) do
		if other ~= tab then
			set[bufnr] = nil
		end
	end
	owned[tab][bufnr] = true
	return true
end

--- 从所有 tab 里移除该 buffer 的归属
---@param bufnr integer
function M.forget(bufnr)
	for _, set in pairs(owned) do
		set[bufnr] = nil
	end
end

--- tab 的归属集合（可能为 nil）
---@param tab integer
---@return table<integer, true>|nil
function M.owned(tab)
	return owned[tab]
end

---@param tab integer
---@param bufnr integer
---@return boolean
function M.is_owned(tab, bufnr)
	local set = owned[tab]
	return set ~= nil and set[bufnr] == true
end

---@return integer[]
function M.tabs()
	local out = {}
	for tab in pairs(owned) do
		out[#out + 1] = tab
	end
	return out
end

--- 丢弃整个 tab 的归属，返回被丢弃的集合
---@param tab integer
---@return table<integer, true>
function M.drop_tab(tab)
	local set = owned[tab]
	owned[tab] = nil
	return set or {}
end

--- 整体替换归属表（会话恢复用）
---@param map table<integer, table<integer, true>>
function M.replace(map)
	owned = map or {}
end

function M.reset()
	owned = {}
end

--- tab 里「真正在编辑文件」的窗口显示的 buffer
---@param tab integer
---@return integer[]
function M.window_buffers(tab)
	local seen, out = {}, {}
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return out
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if not util.is_ephemeral_win(win) then
			local bufnr = vim.api.nvim_win_get_buf(win)
			if not seen[bufnr] then
				seen[bufnr] = true
				out[#out + 1] = bufnr
			end
		end
	end
	return out
end

--- tab 关联的完整 buffer 集合：归属表 ∪ 窗口里显示的
---@param tab integer
---@return integer[]
function M.tab_buffers(tab)
	local seen, out = {}, {}
	local function add(bufnr)
		if seen[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		seen[bufnr] = true
		out[#out + 1] = bufnr
	end
	for _, bufnr in ipairs(M.window_buffers(tab)) do
		add(bufnr)
	end
	for bufnr in pairs(owned[tab] or {}) do
		add(bufnr)
	end
	return out
end

--- buffer 是否正显示在别的 tab 的真实窗口里
---@param bufnr integer
---@param tab integer
---@return boolean
function M.displayed_elsewhere(bufnr, tab)
	for _, other in ipairs(vim.api.nvim_list_tabpages()) do
		if other ~= tab then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(other)) do
				if not util.is_ephemeral_win(win) and vim.api.nvim_win_get_buf(win) == bufnr then
					return true
				end
			end
		end
	end
	return false
end

--- tab 的可见集合（relist 与 bufferline 共用的唯一口径）：归属表 ∪ 本 tab 窗口显示的。
---
--- 一个例外：窗口里显示着、归属却在别的 tab、并且确实还在那个 tab 的窗口里显示时，
--- 不算本 tab 可见。`:tabnew` 就是这种情况——TabEnter 触发时新 tab 的窗口里还是上一个
--- tab 的 buffer，若照窗口快照算，上一个 tab 的 buffer 会一直留在 listed 里
--- （直到下一次 TabEnter 才自愈），:ls / :bnext / picker 都会看到别的 tab 的文件。
---@param tab integer
---@return table<integer, true>
function M.visible_set(tab)
	local set = {}
	local mine = owned[tab] or {}
	for bufnr in pairs(mine) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			set[bufnr] = true
		end
	end
	for _, bufnr in ipairs(M.window_buffers(tab)) do
		if mine[bufnr] or not M.displayed_elsewhere(bufnr, tab) then
			set[bufnr] = true
		end
	end
	return set
end

---@return integer|nil
function M.last_tab()
	return last_tab
end

---@param tab integer|nil
function M.set_last_tab(tab)
	last_tab = (tab and vim.api.nvim_tabpage_is_valid(tab)) and tab or nil
end

return M
