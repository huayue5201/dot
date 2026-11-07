-- 会话归属策略。
--
-- resession 的 current_session 只记住「上次 load 的名字」，跟目录无关；
-- 载入 A 之后在 B 里干活，autosave（定时器 / VimLeavePre）会走
-- save_all() → save(current_session)，把 B 的 buffer、tab cwd 写回 A.json。
-- 结果就是「明明存的 A，下次打开成了 B」。
--
-- 这里在写入前比对「当前各 tab 的根」和「会话文件里记录的根」：没有交集
-- 就拒绝覆盖（属于别的项目），而不是静默写坏。同一会话里新开一个别的项目的
-- tab 不会被误判——只要还有一个当前 tab 的根与会话里的根重合就允许保存。
--
-- 本模块只做策略；读写会话文件、载入后的 cwd 修正、干净 tab 复用都在 store.lua。
local M = {}

local store = require("feat.tab_workspace.store")

---@param path string?
---@return string?
local function norm(path)
	return store.norm(path)
end

--- 会话文件里记录的根目录集合
---@param data table
---@return table<string, true>
function M.roots_of_data(data)
	local roots = {}
	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" then
			local dir = norm(tab.cwd)
			if dir then
				roots[dir] = true
			end
		end
	end
	-- 只在「会话里没存任何 tab 根」时才退回 global.cwd。
	-- global.cwd 是保存时活动 tab 的目录，可能是 /tmp、$HOME 这类很宽的目录，
	-- 拿它做归属判断会让会话「命中」所有项目。旧会话（全用 :cd 那种）只能靠它。
	if next(roots) == nil and type(data.global) == "table" then
		local dir = norm(data.global.cwd)
		if dir then
			roots[dir] = true
		end
	end
	return roots
end

--- 当前每个 tab 的根目录集合（统一走 root.cwd，避免三份 getcwd 实现）
---@return table<string, true>
function M.current_roots()
	local root = require("feat.tab_workspace.root")
	local roots = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local dir = norm(root.cwd(tab))
		if dir then
			roots[dir] = true
		end
	end
	return roots
end

--- 读会话文件（走 store，已含 terminal 清洗与 cwd 兜底）
---@param name string
---@param opts? table
---@return table?
function M.read(name, opts)
	return store.read(name, opts)
end

--- 当前工作区是否能覆盖这个会话
---@param name string
---@param opts? table
---@return boolean
function M.fits(name, opts)
	local data = M.read(name, opts)
	if type(data) ~= "table" then
		-- 会话文件不存在/读不出来：按新会话处理，允许写
		return true
	end
	local theirs = M.roots_of_data(data)
	if next(theirs) == nil then
		return true
	end
	local mine = M.current_roots()
	for root in pairs(mine) do
		if theirs[root] then
			return true
		end
	end
	return false
end

--- 带保护的自动保存（替代 resession 自带的 autosave）
---@param opts? table
function M.autosave(opts)
	local current = store.current()
	if current and not M.fits(current) then
		return
	end
	store.save_all(opts)
end

--- 注册带保护的 autosave：定时器 + 退出时各一次
---@param opts? { interval?: integer, notify?: boolean }
function M.setup_autosave(opts)
	opts = opts or {}
	local interval = opts.interval or 60
	local uv = vim.uv or vim.loop
	if M._timer then
		M._timer:close()
		M._timer = nil
	end
	local group = vim.api.nvim_create_augroup("TabWorkspaceSessionAutosave", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			M.autosave({ notify = false })
		end,
	})
	M._timer = assert(uv.new_timer())
	M._timer:start(
		interval * 1000,
		interval * 1000,
		vim.schedule_wrap(function()
			M.autosave({ notify = opts.notify == true })
		end)
	)
end

--- 测试/退出用：停掉定时器
function M.stop_autosave()
	if M._timer then
		M._timer:close()
		M._timer = nil
	end
end

return M
