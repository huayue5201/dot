-- buffer 归属：记录每个 buffer 属于哪个 tab，并负责 listed 状态与会话导出/恢复。
local M = {}

local util = require("feat.tab_workspace.util")

---@type table<integer, table<integer, boolean>> tabpage handle -> set of bufnrs
local ownership = {}

-- 我们自己改 buflisted 时置 true：Neovim 在把 buflisted 置 false 时会触发 BufDelete，
-- 需要忽略这个伪事件，否则会误把 buffer 从归属表里删掉。
local toggling = false

-- 上一个 tab（用于 alternate）
local last_tab

local function claim(tab, bufnr)
	if not util.is_workspace_buf(bufnr) then
		return
	end
	-- 移动语义：一个 buffer 只属于一个 tab（最近出现的地方）
	for _, set in pairs(ownership) do
		set[bufnr] = nil
	end
	ownership[tab] = ownership[tab] or {}
	ownership[tab][bufnr] = true
end

local function forget(bufnr)
	for _, set in pairs(ownership) do
		set[bufnr] = nil
	end
end

local function prune_closed_tabs()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end
	local orphans = {}
	for tab, set in pairs(ownership) do
		if not valid[tab] then
			for bufnr in pairs(set) do
				orphans[bufnr] = true
			end
			ownership[tab] = nil
		end
	end
	if last_tab and not valid[last_tab] then
		last_tab = nil
	end

	-- 会话加载期间 tab 会被成批关掉/重建，此时不能删旧 buffer：
	-- resession 可能还要按名字恢复它们。只清掉失效 tab 的归属即可。
	if util.resession_loading() then
		return
	end

	-- 关闭 tab 后，只属于它、且不在任何窗口里的 buffer 不会自己消失：
	-- 之前只是被 buflisted=false 藏起来，仍占内存、留在 :ls! 里。
	-- 未修改的直接删掉；有未保存修改的保留并提示（避免静默丢数据）。
	local kept_modified = 0
	for bufnr in pairs(orphans) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			if #vim.fn.win_findbuf(bufnr) == 0 and not vim.bo[bufnr].modified and util.is_workspace_buf(bufnr) then
				pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
			elseif vim.bo[bufnr].modified then
				kept_modified = kept_modified + 1
			end
		end
	end
	if kept_modified > 0 then
		vim.notify(
			string.format("关闭工作区后有 %d 个未保存 buffer 仍保留（:ls! 可见）", kept_modified),
			vim.log.levels.WARN
		)
	end
end

--- 该 tab 关联的所有 buffer（窗口里的 + 归属表里的）
---@param tab integer
---@return integer[]
local function tab_buffers(tab)
	local seen, out = {}, {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		local bufnr = vim.api.nvim_win_get_buf(win)
		if not seen[bufnr] then
			seen[bufnr] = true
			out[#out + 1] = bufnr
		end
	end
	for bufnr in pairs(ownership[tab] or {}) do
		if not seen[bufnr] then
			seen[bufnr] = true
			out[#out + 1] = bufnr
		end
	end
	return out
end

--- 渲染期判定：该 buffer 是否属于当前 tab（归属表里有，或正显示在当前 tab 的非浮窗里）。
--- 给 bufferline 的 custom_filter 用：切 tab 时 buflisted 的更新发生在首次重绘之后
--- （BufEnter/WinEnter 早于 TabEnter，状态栏等会先触发一次重绘），只按归属过滤，
--- 第一帧就不会画出别的 tab 的 buffer。buflisted 仍是全局真值，由 relist 维护。
---@param bufnr integer
---@return boolean
function M.is_current_tab_buf(bufnr)
	if not util.is_workspace_buf(bufnr) then
		return false
	end
	local cur = vim.api.nvim_get_current_tabpage()
	if ownership[cur] and ownership[cur][bufnr] then
		return true
	end
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(cur)) do
		if not util.is_float_win(win) and vim.api.nvim_win_get_buf(win) == bufnr then
			return true
		end
	end
	return false
end

--- 按「当前 tab 的归属」重设所有 buffer 的 buflisted
function M.relist()
	local cur = vim.api.nvim_get_current_tabpage()
	prune_closed_tabs()
	if util.resession_loading() then
		return
	end
	-- 不在这里按窗口改归属：切 tab 的 TabEnter 早于新窗口拿到目标 buffer，
	-- 此时窗口里还是上一个 tab 的 buffer，claim 会把它抢过来（tab2 里凭空多一个）。
	-- 但窗口里实际显示的 buffer 必须 listed，否则 :tab split / 同一 buffer 开在
	-- 多个 tab 时会出现「窗口里看得见，bufferline 却空白」。所以只跟着 listed，
	-- 归属仍由 BufWinEnter/BufEnter 的 claim 维护（渲染期再由 is_current_tab_buf 过滤）。
	local owned = ownership[cur] or {}
	local shown = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(cur)) do
		if not util.is_float_win(win) then
			shown[vim.api.nvim_win_get_buf(win)] = true
		end
	end

	-- 改 buflisted=false 会触发伪 BufDelete，其他插件会误以为 buffer 被删了
	-- （例如 todo2 会因此取消待写入的防抖同步、清掉标签筛选）。
	-- 这里只压掉 BufDelete；保留 BufAdd，让 neo-tree 的 opened markers 在
	-- 切回 tab 时仍能刷新。
	local prev_ei = vim.o.eventignore
	vim.o.eventignore = prev_ei == "" and "BufDelete" or (prev_ei .. ",BufDelete")
	toggling = true
	local ok, err = pcall(function()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if util.is_workspace_buf(bufnr) then
				vim.bo[bufnr].buflisted = owned[bufnr] == true or shown[bufnr] == true
			end
		end
	end)
	toggling = false
	vim.o.eventignore = prev_ei
	if not ok then
		error(err)
	end
	-- 改完 buflisted 后请求重绘 tabline：会话恢复（post_load）时没有 TabEnter/BufAdd，
	-- 而且 unlist 时 BufDelete 被压掉了，bufferline 收不到事件。
	-- 走 bufferline 自己的去重调度，避免和它的 autocmd 在同一轮里重复渲染（闪烁）。
	local bl = package.loaded["bufferline"]
	if type(bl) == "table" and type(bl.redraw) == "function" then
		bl.redraw()
	else
		vim.schedule(function()
			pcall(vim.cmd, "redrawtabline")
		end)
	end
end

--- 导出每 tab 的归属（buffer 名），供 resession 扩展保存进会话文件
---@return table<string, string[]>
function M.export()
	local out = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local set = ownership[tab]
		if set then
			local names = {}
			for bufnr in pairs(set) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					local name = vim.api.nvim_buf_get_name(bufnr)
					if name ~= "" then
						names[#names + 1] = name
					end
				end
			end
			if #names > 0 then
				out[tostring(vim.api.nvim_tabpage_get_number(tab))] = names
			end
		end
	end
	return out
end

--- 用会话里的归属替换当前归属表（不 relist，由调用方决定时机）。
---@param map? table<string, string[]>
---@return boolean 是否有可恢复的归属
function M.replace(map)
	if type(map) ~= "table" or next(map) == nil then
		return false
	end
	local byname = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		if name ~= "" then
			byname[name] = bufnr
			byname[vim.fn.fnamemodify(name, ":p")] = bufnr
		end
	end
	local restored = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local names = map[tostring(vim.api.nvim_tabpage_get_number(tab))]
		if names then
			restored[tab] = {}
			for _, name in ipairs(names) do
				local bufnr = byname[name] or byname[vim.fn.fnamemodify(name, ":p")]
				if bufnr then
					restored[tab][bufnr] = true
				end
			end
		end
	end
	ownership = restored
	return true
end

--- 从当前窗口布局重建归属（会话加载后调用）
function M.rebuild()
	ownership = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
			if vim.api.nvim_win_get_config(win).relative == "" then
				claim(tab, vim.api.nvim_win_get_buf(win))
			end
		end
	end
	M.relist()
end

---@return boolean 当前是否正在批量改 buflisted
function M.is_toggling()
	return toggling
end

---@return integer|nil
function M.get_last_tab()
	return last_tab
end

---@param tab integer|nil
function M.set_last_tab(tab)
	last_tab = tab
end

M.claim = claim
M.forget = forget
M.prune_closed_tabs = prune_closed_tabs
M.tab_buffers = tab_buffers

return M
