-- json_store/data/namespace.lua
local config = require("json_store.core.config")
local project = require("json_store.core.project")
local store = require("json_store.core.store")

local M = {}

-- 获取 namespace store
local function get_namespace_store(project_obj, namespace)
	if not project_obj.stores.namespaces[namespace] then
		local path = project_obj.paths.namespaces_dir .. "/" .. namespace .. ".json"
		project_obj.stores.namespaces[namespace] = {
			path = path,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
		}
	end
	return project_obj.stores.namespaces[namespace]
end

-- 根据 namespace 决定使用 global 还是 project
local function resolve_project(namespace, use_global)
	local cfg = config.get()

	if use_global or vim.tbl_contains(cfg.global_namespaces, namespace) then
		return project.ensure_project("global", true)
	end

	return project.get_current_project()
end

-- 写入
function M.set(namespace, key, value, file_id, use_global)
	local _, project_obj = resolve_project(namespace, use_global)
	local store_obj = get_namespace_store(project_obj, namespace)
	local data = store.load(store_obj)

	data[key] = data[key] or {}

	if file_id then
		data[key][file_id] = value
	else
		data[key] = value
	end

	store.mark_dirty(store_obj)
end

-- 读取
function M.get(namespace, key, file_id, use_global)
	-- 特殊逻辑：todo_links / code_links 先查全局
	if not use_global and (namespace == "todo_links" or namespace == "code_links") then
		local _, global_project = project.ensure_project("global", true)
		local store_obj = get_namespace_store(global_project, namespace)
		local data = store.load(store_obj)

		if data[key] then
			if file_id and type(data[key]) == "table" then
				return data[key][file_id]
			end
			return data[key]
		end
	end

	local _, project_obj = resolve_project(namespace, use_global)
	local store_obj = get_namespace_store(project_obj, namespace)
	local data = store.load(store_obj)

	local v = data[key]
	if file_id and type(v) == "table" then
		return v[file_id]
	end
	return v
end

-- 删除
function M.delete(namespace, key, file_id, use_global)
	local _, project_obj = resolve_project(namespace, use_global)
	local store_obj = get_namespace_store(project_obj, namespace)
	local data = store.load(store_obj)

	local v = data[key]
	if not v then
		return
	end

	if file_id and type(v) == "table" then
		v[file_id] = nil
		if vim.tbl_isempty(v) then
			data[key] = nil
		end
	else
		data[key] = nil
	end

	store.mark_dirty(store_obj)
end

-- 获取整个 namespace
function M.get_all(namespace, use_global)
	local _, project_obj = resolve_project(namespace, use_global)
	local store_obj = get_namespace_store(project_obj, namespace)
	return store.load(store_obj)
end

return M
