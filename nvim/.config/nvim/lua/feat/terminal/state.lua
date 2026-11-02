-- 终端登记表：tab -> 该 tab 的终端 buffer（tab 句柄做 key）。
--
-- 为什么用 tab 句柄而不是 tab 序号：`:tabmove` / 关掉前面的 tab 会让序号整体平移，
-- 序号做 key 归属就错位。tab 句柄在整个会话内稳定（:tabmove 不变），只在关 tab 后
-- 失效——失效的那些由 sweep() 一次性收尾（连进程一起清）。
local M = {}

---@class FeatTermScope
---@field terms integer[]
---@field active integer|nil

---@type table<integer, FeatTermScope>
local scopes = {}

-- 全局序号：终端命名 Term 1 / Term 2 …，不随 tab 重置，避免同名 buffer
local counter = 0

--- 下一个终端序号
---@return integer
function M.next_index()
	counter = counter + 1
	return counter
end

---@param tab integer
---@return FeatTermScope
local function ensure(tab)
	local s = scopes[tab]
	if not s then
		s = { terms = {}, active = nil }
		scopes[tab] = s
	end
	return s
end

--- 登记终端；已登记则只更新 active
---@param tab integer
---@param bufnr integer
function M.add(tab, bufnr)
	local s = ensure(tab)
	for _, b in ipairs(s.terms) do
		if b == bufnr then
			s.active = bufnr
			return
		end
	end
	s.terms[#s.terms + 1] = bufnr
	s.active = bufnr
end

--- 从所有 tab 注销该终端（buffer 被删掉时用）
---@param bufnr integer
function M.remove(bufnr)
	for tab, s in pairs(scopes) do
		local kept = {}
		for _, b in ipairs(s.terms) do
			if b ~= bufnr then
				kept[#kept + 1] = b
			end
		end
		s.terms = kept
		if s.active == bufnr then
			s.active = nil
		end
		if #kept == 0 then
			scopes[tab] = nil
		end
	end
end

--- 把终端改归到 tab（终端 buffer 被 :b 到别的 tab 时收编）
---@param tab integer
---@param bufnr integer
function M.adopt(tab, bufnr)
	M.remove(bufnr)
	M.add(tab, bufnr)
end

--- 终端登记在哪个 tab
---@param bufnr integer
---@return integer|nil
function M.tab_of(bufnr)
	for tab, s in pairs(scopes) do
		for _, b in ipairs(s.terms) do
			if b == bufnr then
				return tab
			end
		end
	end
	return nil
end

--- 有终端登记的 tab（按 tab 序号排序），给侧栏做全量总览用
---@return integer[]
function M.tabs()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end
	local out = {}
	for tab, s in pairs(scopes) do
		if valid[tab] and #s.terms > 0 then
			out[#out + 1] = tab
		end
	end
	table.sort(out, function(a, b)
		return vim.api.nvim_tabpage_get_number(a) < vim.api.nvim_tabpage_get_number(b)
	end)
	return out
end

--- tab 的有效终端列表（顺手清掉已失效的 buffer）
---@param tab integer
---@return integer[]
function M.list(tab)
	local s = scopes[tab]
	if not s then
		return {}
	end
	local out = {}
	for _, b in ipairs(s.terms) do
		if vim.api.nvim_buf_is_valid(b) then
			out[#out + 1] = b
		end
	end
	s.terms = out
	return out
end

--- 取/设该 tab 的活动终端
---@param tab integer
---@param bufnr integer|nil
---@return integer|nil
function M.active(tab, bufnr)
	local s = ensure(tab)
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		s.active = bufnr
	end
	if s.active and not vim.api.nvim_buf_is_valid(s.active) then
		s.active = nil
	end
	if not s.active then
		s.active = M.list(tab)[1]
	end
	return s.active
end

--- 清掉已关闭 tab 的登记，返回它们的终端 buffer（调用方负责 bwipeout）
---@return integer[]
function M.sweep()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end
	local dead = {}
	for tab, s in pairs(scopes) do
		if not valid[tab] then
			for _, b in ipairs(s.terms) do
				dead[#dead + 1] = b
			end
			scopes[tab] = nil
		end
	end
	return dead
end

return M
