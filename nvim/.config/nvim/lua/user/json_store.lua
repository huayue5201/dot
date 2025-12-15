-- lua/user/json_store.lua
local M = {}

-- ================= 内部状态 =================

local _default_config = {
	file_path = vim.fn.stdpath("cache") .. "/project_states/",
	auto_save = true,
	save_delay_ms = 2000,
}

local _stores = {}

local function _ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

local function _new_instance(config)
	_ensure_dir(config.file_path)
	return {
		file_path = config.file_path,
		data = nil,
		auto_save = config.auto_save,
		save_delay = config.save_delay_ms,
		_dirty = false,
		_save_timer = nil,
	}
end

-- ================= 项目标识 =================

local function _sanitize_project_name(name)
	local basename = vim.fn.fnamemodify(name, ":t")
	if #basename > 50 then
		basename = basename:sub(1, 50)
	end
	if #basename == 0 then
		basename = "project"
	end
	return basename
end

local function _get_project_key()
	local cwd = vim.fn.getcwd()
	if not cwd or cwd == "" then
		cwd = vim.loop.cwd()
	end
	local project_name = _sanitize_project_name(cwd)
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return (project_name .. "_" .. hash):gsub("[^%w_%-]", "_")
end

-- ================= IO =================

local function _load(store, project_key)
	if store.data then
		return store.data
	end
	local path = store.file_path .. project_key .. ".json"
	local f = io.open(path, "r")
	if not f then
		store.data = {}
		return store.data
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	store.data = (ok and type(data) == "table") and data or {}
	return store.data
end

local function _save(store, project_key)
	if not store.data then
		return
	end
	local path = store.file_path .. project_key .. ".json"
	local json = vim.json.encode(store.data, { indent = "  ", sort_keys = true })
	local f = io.open(path, "w")
	if not f then
		return
	end
	f:write(json)
	f:close()
	store._dirty = false
end

local function _schedule_save(store, project_key)
	if not store.auto_save or store._save_timer then
		return
	end
	store._save_timer = vim.defer_fn(function()
		_save(store, project_key)
		store._save_timer = nil
	end, store.save_delay)
end

local function _ensure_store(project_key)
	if not _stores[project_key] then
		_stores[project_key] = _new_instance(_default_config)
	end
	return _stores[project_key]
end

-- ================= 批量操作工具 =================

local function _batch_op(op, namespace, keys_or_entries, file_id)
	local project_key = _get_project_key()
	local store = _ensure_store(project_key)
	local data = _load(store, project_key)
	data[namespace] = data[namespace] or {}
	local ns = data[namespace]

	if op == "set" then
		for key, value in pairs(keys_or_entries) do
			if file_id then
				ns[key] = ns[key] or {}
				ns[key][file_id] = value
			else
				ns[key] = value
			end
		end
		store._dirty = true
		_schedule_save(store, project_key)
	elseif op == "delete" then
		for _, key in ipairs(keys_or_entries) do
			if file_id and ns[key] then
				ns[key][file_id] = nil
				if vim.tbl_isempty(ns[key]) then
					ns[key] = nil
				end
			else
				ns[key] = nil
			end
		end
		store._dirty = true
		_schedule_save(store, project_key)
	elseif op == "get" then
		local results = {}
		for _, key in ipairs(keys_or_entries) do
			if file_id then
				results[key] = ns[key] and ns[key][file_id] or nil
			else
				results[key] = ns[key]
			end
		end
		return results
	end
end

-- ================= Public API =================

--- 设置单个键值对
-- 示例：存储项目的窗口布局
-- json_store.set("window_layout", "main_split", {width = 800, height = 600})
-- 示例（带文件ID）：存储文件特定的光标位置
-- json_store.set("cursor_pos", "line_col", {20, 5}, "main.lua")
function M.set(namespace, key, value, file_id)
	_batch_op("set", namespace, { [key] = value }, file_id)
end

--- 获取单个键值
-- 示例：读取窗口布局
-- local layout = json_store.get("window_layout", "main_split")
-- 示例（带文件ID）：读取文件特定光标位置
-- local pos = json_store.get("cursor_pos", "line_col", "main.lua")
function M.get(namespace, key, file_id)
	local res = _batch_op("get", namespace, { key }, file_id)
	return res[key]
end

--- 获取命名空间下所有数据
-- 示例：获取所有窗口布局数据
-- local all_layouts = json_store.get_all("window_layout")
function M.get_all(namespace)
	local project_key = _get_project_key()
	local store = _ensure_store(project_key)
	local data = _load(store, project_key)
	return data[namespace] or {}
end

--- 删除单个键
-- 示例：删除特定的窗口布局
-- json_store.delete("window_layout", "main_split")
-- 示例（带文件ID）：删除文件特定设置
-- json_store.delete("cursor_pos", "line_col", "main.lua")
function M.delete(namespace, key, file_id)
	_batch_op("delete", namespace, { key }, file_id)
end

--- 批量设置多个键值对
-- 示例：批量设置项目配置
-- json_store.set_many("project_config", {
--     theme = "dark",
--     font_size = 14,
--     tab_width = 4
-- })
-- 示例（带文件ID）：批量设置文件状态
-- json_store.set_many("file_states", {
--     modified = true,
--     last_accessed = os.time()
-- }, "main.lua")
function M.set_many(namespace, entries, file_id)
	_batch_op("set", namespace, entries, file_id)
end

--- 批量删除多个键
-- 示例：清理临时数据
-- json_store.delete_many("temp_data", {"cache1", "cache2", "cache3"})
-- 示例（带文件ID）：清理多个文件的特定设置
-- json_store.delete_many("file_settings", {"indent", "encoding"}, "main.lua")
function M.delete_many(namespace, keys, file_id)
	_batch_op("delete", namespace, keys, file_id)
end

--- 批量获取多个键值
-- 示例：同时获取多个配置项
-- local configs = json_store.get_many("project_config", {"theme", "font_size", "tab_width"})
-- 示例（带文件ID）：获取多个文件属性
-- local attrs = json_store.get_many("file_attrs", {"size", "type"}, "main.lua")
function M.get_many(namespace, keys, file_id)
	return _batch_op("get", namespace, keys, file_id)
end

--- 立即保存数据到文件（跳过延迟）
-- 示例：在插件卸载前确保数据已保存
-- json_store.save()
function M.save()
	local project_key = _get_project_key()
	local store = _ensure_store(project_key)
	_save(store, project_key)
end

--- 获取当前项目的存储文件路径
-- 示例：用于调试或备份存储文件
-- local store_file = json_store.get_current_project_file()
-- print("数据存储在：" .. store_file)
function M.get_current_project_file()
	local project_key = _get_project_key()
	return _ensure_store(project_key).file_path .. project_key .. ".json"
end

return M
