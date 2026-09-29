-- lua/lsp-config/state.lua
---@brief 统一 LSP 状态持久化层
-- 解决三件事：
--   1. 动态解析当前（或指定 buffer 所属）项目的 store，避免模块加载时静态绑定
--   2. 统一状态词表为布尔值，并兼容旧的 on/off、active/inactive 字符串
--   3. 读时给默认值，只在用户真正改变时写盘
local M = {}

---各键默认值（集中管理）
local DEFAULTS = {
	["lsp.diagnostics"] = true,
	["lsp.inlay_hints"] = true,
}

---订阅者与被订阅过的 store 实例（按实例身份去重）
local subscribers = {}
local subscribed = {}

---把一个 store 实例接入订阅（同一实例只订阅一次）
---@param s table|nil
local function attach(s)
	if not s then
		return
	end
	local id = tostring(s)
	if subscribed[id] then
		return
	end
	subscribed[id] = true
	for _, cb in ipairs(subscribers) do
		s:on("set", function(payload)
			cb(payload.key, payload.value)
		end)
	end
end

---解析 store：优先按 buffer 所属项目，缺省按当前工作目录
---@param bufnr number|nil
---@return table|nil
local function store(bufnr)
	local ok, nvim_store = pcall(require, "nvim-store3")
	if not ok then
		return nil
	end

	local name = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
	local s
	if name ~= "" and not name:match("^%a[%w+.-]*://") then
		s = nvim_store.project({ from = name })
	else
		s = nvim_store.project()
	end

	attach(s)
	return s
end

---兼容旧数据：on/active/enabled -> true，off/inactive/disabled -> false
---@param v any
---@return boolean|nil
local function normalize(v)
	if v == nil or type(v) == "boolean" then
		return v
	end
	if v == "on" or v == "active" or v == "enabled" then
		return true
	end
	if v == "off" or v == "inactive" or v == "disabled" then
		return false
	end
	return nil
end

---读取状态，未设置时返回默认值
---@param key string
---@param bufnr number|nil
---@param default boolean|nil 覆盖内置默认（用于内置表未覆盖的键，如各 LSP server）
---@return boolean|nil
function M.get(key, bufnr, default)
	local s = store(bufnr)
	if not s then
		return default ~= nil and default or DEFAULTS[key]
	end
	local v = normalize(s:get(key))
	if v == nil then
		return default ~= nil and default or DEFAULTS[key]
	end
	return v
end

---写入状态（仅在用户真正改变时调用）
---@param key string
---@param value boolean
---@param bufnr number|nil
function M.set(key, value, bufnr)
	local s = store(bufnr)
	if s then
		s:set(key, value)
	end
end

---翻转状态并返回新值
---@param key string
---@param bufnr number|nil
---@param default boolean|nil
---@return boolean
function M.toggle(key, bufnr, default)
	local new = not (M.get(key, bufnr, default) == true)
	M.set(key, new, bufnr)
	return new
end

---订阅 store 的 set 事件（之后每个被解析到的项目实例都会自动接入）
---@param cb fun(key: string, value: any)
function M.subscribe(cb)
	table.insert(subscribers, cb)
	attach(store())
end

return M
