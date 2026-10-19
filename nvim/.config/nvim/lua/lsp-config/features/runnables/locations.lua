-- lua/lsp-config/features/runnables/locations.lua
-- 通用「把一组 LSP Location 展示出来」的工具，供各语言后端复用。
--
-- 各 server 的 code lens 命令名和参数形状各不相同，但语义往往是同一件事：
-- 「跳到某个位置」或「列出 N 个位置」。本模块只做两件事：
--   1. 从任意嵌套的 arguments 里把 Location / LocationLink 挖出来并归一化
--   2. 渲染成跳转（1 个）或 quickfix 列表（多个）
--
-- 已知形状（实际取自各 server）：
--   rust-analyzer.showReferences: [uri|{uri=...}, position, Location[]]
--   clangd.showLocations:         [Location, Location[]]      （第一个是符号本身）
--   通用 vscode 风格:             [uri, position, Location[]]
-- 因为只用「形状」而不看命令名，新 server 通常不需要额外代码。

local M = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO)
end

---是否是 LSP Location / LocationLink
---@param t any
---@return boolean
local function is_location(t)
	if type(t) ~= "table" then
		return false
	end
	if type(t.uri) == "string" and type(t.range) == "table" then
		return true
	end
	if type(t.targetUri) == "string" then
		return true -- LocationLink
	end
	return false
end

---归一化成 { uri, range }（LocationLink → targetUri/targetSelectionRange）
---@param t table
---@return table
local function normalize(t)
	if type(t.uri) == "string" then
		return { uri = t.uri, range = t.range }
	end
	return { uri = t.targetUri, range = t.targetSelectionRange or t.targetRange }
end

---递归收集 arguments 里的所有位置
---@param v any
---@param acc table[]
local function collect(v, acc)
	if is_location(v) then
		acc[#acc + 1] = normalize(v)
		return
	end
	if type(v) ~= "table" then
		return
	end
	for _, item in pairs(v) do
		if type(item) == "table" then
			collect(item, acc)
		end
	end
end

---从命令参数里挖出位置列表
---@param args table|nil
---@return table[] locations 归一化后的位置
---@return string|nil target_uri 目标符号自身所在文件（用于标题）
function M.extract(args)
	local acc = {}
	collect(args or {}, acc)
	-- 去重（clangd 的 showLocations 会把符号自身也放进第二个参数）
	local seen, uniq = {}, {}
	for _, loc in ipairs(acc) do
		local key = table.concat({
			loc.uri,
			loc.range.start.line,
			loc.range.start.character,
			loc.range["end"] and loc.range["end"].line or 0,
		}, ":")
		if not seen[key] then
			seen[key] = true
			uniq[#uniq + 1] = loc
		end
	end
	local target_uri = uniq[1] and uniq[1].uri or nil
	return uniq, target_uri
end

---@param loc table 归一化后的位置
---@return boolean
local function jump(loc)
	local items = vim.lsp.util.locations_to_items({ loc }, "utf-16")
	if not items or #items == 0 then
		return false
	end
	vim.lsp.util.show_document(loc, "utf-16", { focus = true })
	return true
end

---把位置列表展示出来：1 个直接跳转，多个进 quickfix
---@param locations table[] 归一化后的位置
---@param title string|nil quickfix 标题
---@return boolean handled
function M.show(locations, title)
	if not locations or #locations == 0 then
		return false
	end
	if #locations == 1 then
		return jump(locations[1])
	end
	local ok, items = pcall(vim.lsp.util.locations_to_items, locations, "utf-16")
	if not ok or not items or #items == 0 then
		notify("无法解析位置列表", vim.log.levels.ERROR)
		return false
	end
	for _, item in ipairs(items) do
		item.text = item.text or ""
	end
	vim.fn.setqflist({}, " ", { title = title or "References", items = items })
	vim.cmd("copen")
	return true
end

---@param uri string|nil
---@return string|nil
local function label(uri)
	if not uri then
		return nil
	end
	local ok, fname = pcall(vim.uri_to_fname, uri)
	if ok and fname then
		return ("References of %s"):format(vim.fs.basename(fname))
	end
	return nil
end

---通用兜底：把命令参数里的位置展示出来（不关心命令名）
---用于 server 要求「客户端自己处理命令」但我们没写专用 handler 的情况，
---例如 clangd 的 clangd.showLocations / clangd.typeHierarchy。
---@param args table|nil
---@param title string|nil
---@return boolean handled 参数里确实有位置、并且已经展示出来了
function M.show_from_args(args, title)
	local locations, target_uri = M.extract(args)
	if #locations == 0 then
		return false
	end
	return M.show(locations, title or label(target_uri))
end

return M
