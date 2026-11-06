-- 工作区的多个根：主根（tab 的 cwd，见 root.lua）+ 若干辅助根（本模块）。
--
-- 为什么需要：Neovim 的 cwd 每个 tab 只有一个（`:tcd`），而「一个工作区里放多个
-- 项目」只能靠一份"额外根"列表来表达。约定：
--   * cwd 永远是主根，相对路径、终端、:make 都落在主根上（不假装能改）；
--   * 辅助根只影响显式的多根消费者（neo-tree 的 workspace 源、搜索、会话）。
-- 状态按 tabpage 句柄存，和 state.lua / root.lua 的键一致 —— 工作区没有独立 ID。
local M = {}

local DIR_EVENTS = { "TabWorkspaceRoots" }

-- tabpage -> { [dir] = true }；order 保留用户添加顺序（显示顺序）
local entries = {}
local order = {}

local function fire()
	vim.api.nvim_exec_autocmds("User", { pattern = DIR_EVENTS[1] })
end

--- 规范化：展开 ~、转绝对、解析符号链接、去掉末尾的 /
---@param dir string
---@return string?
local function norm(dir)
	if type(dir) ~= "string" or dir == "" then
		return nil
	end
	local abs = vim.fn.fnamemodify(vim.fn.expand(dir), ":p")
	local real = vim.uv.fs_realpath(abs)
	return (real or abs):gsub("/+$", "")
end

---@param tab? integer tabpage 句柄，默认当前
---@return integer
local function tabkey(tab)
	return tab or vim.api.nvim_get_current_tabpage()
end

--- 丢掉已经关闭的 tab 的记录（tabpage 句柄失效后不会再被访问到）
local function gc()
	for tab in pairs(entries) do
		if not vim.api.nvim_tabpage_is_valid(tab) then
			entries[tab] = nil
			order[tab] = nil
		end
	end
end

--- 辅助根列表（按添加顺序）
---@param tab? integer
---@return string[]
function M.aux(tab)
	gc()
	local key = tabkey(tab)
	local list = order[key]
	if not list then
		return {}
	end
	-- 主根可能已经被改成了某个辅助根（:tcd），那种情况下它不再是"辅助"
	local primary = require("feat.tab_workspace.root").cwd(key)
	local out = {}
	for _, dir in ipairs(list) do
		if dir ~= primary and vim.fn.isdirectory(dir) == 1 then
			out[#out + 1] = dir
		end
	end
	return out
end

--- 主根
---@param tab? integer
---@return string
function M.primary(tab)
	return require("feat.tab_workspace.root").cwd(tabkey(tab))
end

--- 全部根：主根在前，辅助根按添加顺序
---@param tab? integer
---@return string[]
function M.all(tab)
	local out = { M.primary(tab) }
	for _, dir in ipairs(M.aux(tab)) do
		out[#out + 1] = dir
	end
	return out
end

---@param tab? integer
---@return integer
function M.count(tab)
	return #M.all(tab)
end

--- 某个 tab 是否已经有这个根（主根或辅助根）
---@param tab? integer
---@param dir string
---@return boolean
function M.has(tab, dir)
	local target = norm(dir)
	if not target then
		return false
	end
	return vim.tbl_contains(M.all(tab), target)
end

--- 添加辅助根。已经是（主根或辅助根）则返回 false。
---@param tab? integer
---@param dir string
---@return boolean ok
---@return string? reason
function M.attach(tab, dir)
	local key = tabkey(tab)
	local target = norm(dir)
	if not target then
		return false, "empty path"
	end
	if vim.fn.isdirectory(target) == 0 then
		return false, "no such directory: " .. target
	end
	if target == M.primary(key) then
		return false, "already the primary root"
	end
	entries[key] = entries[key] or {}
	order[key] = order[key] or {}
	if entries[key][target] then
		return false, "already attached"
	end
	entries[key][target] = true
	order[key][#order[key] + 1] = target
	fire()
	return true
end

--- 移除辅助根（主根移除不了，它不是辅助根）
---@param tab? integer
---@param dir string
---@return boolean ok
function M.detach(tab, dir)
	local key = tabkey(tab)
	local target = norm(dir)
	if not target or not entries[key] or not entries[key][target] then
		return false
	end
	entries[key][target] = nil
	for i, d in ipairs(order[key] or {}) do
		if d == target then
			table.remove(order[key], i)
			break
		end
	end
	fire()
	return true
end

--- 清空某个 tab 的辅助根
---@param tab? integer
function M.clear(tab)
	local key = tabkey(tab)
	entries[key] = nil
	order[key] = nil
	fire()
end

--- 会话恢复用：整体替换辅助根（不校验，调用方保证来源可信）
---@param tab? integer
---@param dirs string[]
function M.set(tab, dirs)
	local key = tabkey(tab)
	entries[key] = {}
	order[key] = {}
	for _, dir in ipairs(dirs or {}) do
		local target = norm(dir)
		if target and target ~= M.primary(key) and vim.fn.isdirectory(target) == 1 and not entries[key][target] then
			entries[key][target] = true
			order[key][#order[key] + 1] = target
		end
	end
	if next(entries[key]) == nil then
		entries[key] = nil
		order[key] = nil
	end
	fire()
end

--- 主根变了之后对齐：把新主根从辅助根里摘掉（旧主根不自动变成辅助根）
---@param tab? integer
function M.reconcile(tab)
	local key = tabkey(tab)
	local primary = M.primary(key)
	if entries[key] and entries[key][primary] then
		entries[key][primary] = nil
		for i, d in ipairs(order[key] or {}) do
			if d == primary then
				table.remove(order[key], i)
				break
			end
		end
		fire()
	end
end

--- path 落在哪个根里（返回最具体的那个根，没命中返回 nil）
---@param tab? integer
---@param path string
---@return string?
function M.find_root(tab, path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	local abs = vim.fn.fnamemodify(path, ":p")
	local best
	for _, dir in ipairs(M.all(tab)) do
		if abs == dir or abs:sub(1, #dir + 1) == dir .. "/" then
			if not best or #dir > #best then
				best = dir
			end
		end
	end
	return best
end

return M
