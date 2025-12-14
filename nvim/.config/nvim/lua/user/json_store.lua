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

function M.set(namespace, key, value, file_id)
	_batch_op("set", namespace, { [key] = value }, file_id)
end

function M.get(namespace, key, file_id)
	local res = _batch_op("get", namespace, { key }, file_id)
	return res[key]
end

function M.get_all(namespace)
	local project_key = _get_project_key()
	local store = _ensure_store(project_key)
	local data = _load(store, project_key)
	return data[namespace] or {}
end

function M.delete(namespace, key, file_id)
	_batch_op("delete", namespace, { key }, file_id)
end

function M.set_many(namespace, entries, file_id)
	_batch_op("set", namespace, entries, file_id)
end

function M.delete_many(namespace, keys, file_id)
	_batch_op("delete", namespace, keys, file_id)
end

function M.get_many(namespace, keys, file_id)
	return _batch_op("get", namespace, keys, file_id)
end

function M.save()
	local project_key = _get_project_key()
	local store = _ensure_store(project_key)
	_save(store, project_key)
end

function M.get_current_project_file()
	local project_key = _get_project_key()
	return _ensure_store(project_key).file_path .. project_key .. ".json"
end

return M
