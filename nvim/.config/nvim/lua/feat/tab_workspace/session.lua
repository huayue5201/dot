-- 会话（resession）视角的工作区状态：导出每 tab 的 buffer 归属，恢复后重建。
--
-- 时序（resession 的实现细节）：扩展的 on_post_load 在仍然 is_loading() 的时候
-- 调用，此时 relist 会被 util.resession_loading() 挡掉；is_loading() 变 false
-- 之后才 dispatch("post_load") 钩子。所以这里分两步：
--   on_session_restore  —— 记录归属，不动 buflisted
--   on_post_load        —— 加载真正结束后再 relist
local util = require("feat.tab_workspace.util")
local state = require("feat.tab_workspace.state")
local listed = require("feat.tab_workspace.listed")

local M = {}

-- 恢复时已记下归属，等 resession 真正结束加载后再 relist
local pending = false

-- 会话里 tab_workspace 数据的格式版本。
-- v1（旧）：{ ["1"] = {bufname, ...}, ["2"] = {...} } —— 以 tab 序号为键。
--   tab 作用域会话从 tab2 存、在 tab1 载入时键对不上，归属只能整体丢掉。
-- v2：{ v = 2, scoped = bool, list = { { root = ..., names = {bufname...} }, ... } }
--   按 tab 顺序存数组，载入时按顺序对回 tab，序号如何变都不影响。
local FORMAT = 2

---@param tab integer
---@return string?
local function tab_root(tab)
	local ok, dir = pcall(vim.fn.getcwd, -1, vim.api.nvim_tabpage_get_number(tab))
	if ok and type(dir) == "string" and dir ~= "" then
		return dir
	end
	return nil
end

--- 某个 tab 的 buffer 名（已过滤终端/面板/无名 buffer）
---@param tab integer
---@return string[]
local function owned_names(tab)
	local names = {}
	for bufnr in pairs(state.owned(tab) or {}) do
		-- 终端 / 面板 buffer 不进会话：进程没法存盘，恢复出来是死 buffer
		if util.is_saved_buf(bufnr) then
			names[#names + 1] = vim.api.nvim_buf_get_name(bufnr)
		end
	end
	table.sort(names)
	return names
end

--- 导出 buffer 归属，供 resession 扩展写进会话文件。
---@param tabpage? integer 只导出这一个 tab（tab 作用域会话），nil = 导出全部
---@return table
function M.export(tabpage)
	if tabpage then
		return {
			v = FORMAT,
			scoped = true,
			list = { { root = tab_root(tabpage), names = owned_names(tabpage) } },
		}
	end
	local list = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		list[#list + 1] = { root = tab_root(tab), names = owned_names(tab) }
	end
	return { v = FORMAT, list = list }
end

--- 用会话里的归属替换当前归属表（不 relist）。
---@param map? table
---@return boolean 是否记录了归属
function M.restore(map)
	if type(map) ~= "table" or next(map) == nil then
		pending = false
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

	local restored, matched = {}, 0

	---@param tab integer
	---@param names? string[]
	local function assign(tab, names)
		if type(names) ~= "table" then
			return
		end
		local set = {}
		for _, name in ipairs(names) do
			local bufnr = byname[name] or byname[vim.fn.fnamemodify(name, ":p")]
			if bufnr then
				set[bufnr] = true
				matched = matched + 1
			end
		end
		if next(set) then
			restored[tab] = set
		end
	end

	if map.v == FORMAT and type(map.list) == "table" then
		if map.scoped then
			-- tab 作用域会话：归属属于「被载入的那个 tab」，按顺序取第一项
			local entry = map.list[1]
			if entry then
				assign(vim.api.nvim_get_current_tabpage(), entry.names)
			end
		else
			for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
				local entry = map.list[i]
				if entry then
					assign(tab, entry.names)
				end
			end
		end
	else
		-- 旧格式（tab 序号为键）：按当前序号尽力匹配
		for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
			assign(tab, map[tostring(vim.api.nvim_tabpage_get_number(tab))])
		end
	end

	-- 一个都对不上（会话里的文件都被删了）：交给重建兜底
	if matched == 0 then
		pending = false
		return false
	end

	state.replace(restored)
	pending = true
	return true
end

--- 按当前窗口布局重建归属（没有可用导入信息时的兜底）
function M.rebuild()
	state.reset()
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		for _, bufnr in ipairs(state.window_buffers(tab)) do
			state.claim(tab, bufnr)
		end
	end
	listed.relist()
end

--- resession 扩展 on_post_load：此时仍在加载，只记录归属
---@param data? table<string, string[]>
function M.on_session_restore(data)
	M.restore(data)
end

--- 从会话数据里剔除终端 buffer。
---
--- 为什么要做：resession 载入时会对每个存下的 buffer 做 bufadd + bufload，而 bufload 一个
--- `term://` 名字的 buffer 是会把 shell 真拉起来的。旧会话（以及带僵尸 term:// buffer 的会话）
--- 里有这类条目，表现就是「<leader>lsl 加载会话时凭空打开一个终端」。
--- resession 只给 save 提供了 buf_filter，load 没有对应钩子，所以在唯一的读入口
--- （files.load_json_file 的包装，见 lua/plugins/resession.lua）上洗一遍。
---@param data table
---@return table
function M.strip_terminal_bufs(data)
	local function is_term(name)
		return type(name) == "string" and name:find("^term://") ~= nil
	end

	if type(data.buffers) == "table" then
		local keep = {}
		for _, buf in ipairs(data.buffers) do
			if not (type(buf) == "table" and is_term(buf.name)) then
				keep[#keep + 1] = buf
			end
		end
		data.buffers = keep
	end

	if type(data.tab_workspace) == "table" then
		local function clean(names)
			local keep = {}
			for _, name in ipairs(names) do
				if not is_term(name) then
					keep[#keep + 1] = name
				end
			end
			return keep
		end
		if data.tab_workspace.v == FORMAT and type(data.tab_workspace.list) == "table" then
			for _, entry in ipairs(data.tab_workspace.list) do
				if type(entry) == "table" and type(entry.names) == "table" then
					entry.names = clean(entry.names)
				end
			end
		else
			for key, names in pairs(data.tab_workspace) do
				if type(names) == "table" then
					data.tab_workspace[key] = clean(names)
				end
			end
		end
	end

	-- 窗口布局里的叶子也不能指向 term://（wins 可能是 false 或嵌套的分割树）
	local function clean_layout(node, term_found)
		if type(node) ~= "table" then
			return node
		end
		if node[1] == "leaf" then
			local win = node[2]
			if type(win) == "table" and is_term(win.bufname) then
				term_found[1] = true
			end
			return node
		end
		for _, child in ipairs(node[2] or {}) do
			clean_layout(child, term_found)
		end
		return node
	end

	if type(data.tabs) == "table" then
		for _, tab in ipairs(data.tabs) do
			if type(tab) == "table" and type(tab.wins) == "table" then
				local found = { false }
				clean_layout(tab.wins, found)
				-- 整个 tab 只有终端窗口：丢掉布局，交给 resession 的默认单窗口处理
				if found[1] and tab.wins[1] == "leaf" then
					tab.wins = false
				end
			end
		end
	end

	return data
end

--- resession 的 post_load 钩子：加载已结束，可以安全地重排 buflisted
function M.on_post_load()
	if pending then
		pending = false
		listed.relist()
	else
		M.rebuild()
	end
	state.set_last_tab(nil)
end

return M
