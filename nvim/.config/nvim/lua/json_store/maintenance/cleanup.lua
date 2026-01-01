-- json_store/maintenance/cleanup.lua
local config = require("json_store.core.config")
local project = require("json_store.core.project")
local store = require("json_store.core.store")

local M = {}

local function file_exists(path)
	return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

-- 确保 project.stores.project 存在
local function ensure_project_store(project_obj)
	if not project_obj or not project_obj.paths then
		return nil
	end

	project_obj.stores = project_obj.stores or {
		project = nil,
		namespaces = {},
		files = {},
	}

	if not project_obj.stores.project then
		project_obj.stores.project = {
			path = project_obj.paths.project,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
		}
	end

	return project_obj.stores.project
end

-- 清理无效文件引用（file_mappings 指向的文件已不存在）
function M.cleanup_invalid_file_refs(project_obj, limit)
	if not project_obj or not project_obj.paths then
		return 0
	end

	local cfg = config.get()
	limit = limit or cfg.max_file_check_per_run

	local cleaned = 0
	local checked = 0

	local proj_store = ensure_project_store(project_obj)
	if not proj_store then
		return 0
	end

	local proj_data = store.load(proj_store)
	proj_data.file_mappings = proj_data.file_mappings or {}

	for file_id, file_store in pairs(project_obj.stores.files or {}) do
		if checked >= limit then
			break
		end

		local mapping = proj_data.file_mappings[file_id]
		if mapping and not file_exists(mapping.path) then
			-- 删除对应的 file json
			if file_store.path then
				pcall(os.remove, file_store.path)
			end
			-- 从内存中移除
			project_obj.stores.files[file_id] = nil
			-- 从映射中移除
			proj_data.file_mappings[file_id] = nil
			cleaned = cleaned + 1
		end

		checked = checked + 1
	end

	if cleaned > 0 then
		store.mark_dirty(proj_store)
	end

	return cleaned
end

-- 清理孤儿文件（磁盘上有 file_xxx.json，但没有 file_mappings 对应项）
local function cleanup_orphan_files(project_obj)
	if not project_obj or not project_obj.paths then
		return 0
	end

	local cleaned = 0
	local files = vim.fn.glob(project_obj.paths.files_dir .. "/*.json", true, true)

	local proj_store = ensure_project_store(project_obj)
	if not proj_store then
		return 0
	end

	local proj_data = store.load(proj_store)
	proj_data.file_mappings = proj_data.file_mappings or {}

	for _, file_path in ipairs(files) do
		local file_id = vim.fn.fnamemodify(file_path, ":t:r")
		if not proj_data.file_mappings[file_id] then
			pcall(os.remove, file_path)
			if project_obj.stores.files then
				project_obj.stores.files[file_id] = nil
			end
			cleaned = cleaned + 1
		end
	end

	if cleaned > 0 then
		store.mark_dirty(proj_store)
	end

	return cleaned
end

-- 清理所有项目（全局 + 普通）
function M.cleanup_all_projects(opts)
	opts = opts or {}
	local cfg = config.get()

	local limit = opts.limit_per_project or cfg.max_file_check_per_run
	local skip_recent = opts.skip_recent or 3600

	local total = 0
	local now = os.time()

	-- 全局项目
	local _, global_project = project.ensure_project("global", true)
	if now - (global_project.last_access or 0) > skip_recent then
		total = total + M.cleanup_invalid_file_refs(global_project, limit)
		total = total + cleanup_orphan_files(global_project)
	end

	-- 普通项目
	for _, project_obj in pairs(project.get_all_projects() or {}) do
		if now - (project_obj.last_access or 0) > skip_recent then
			total = total + M.cleanup_invalid_file_refs(project_obj, limit)
			total = total + cleanup_orphan_files(project_obj)
		end
	end

	return total
end

-- 清理过期项目（只从内存中移除，不删磁盘目录）
function M.cleanup_stale_projects(max_age)
	local cfg = config.get()
	max_age = max_age or cfg.max_cache_age

	local now = os.time()
	local cleaned = 0

	local projects = project.get_all_projects() or {}
	for key, project_obj in pairs(projects) do
		if not project_obj.is_global and now - (project_obj.last_access or 0) > max_age then
			-- 清理一下无效引用，避免残留
			M.cleanup_invalid_file_refs(project_obj, 50)
			-- 从内存中移除
			projects[key] = nil
			cleaned = cleaned + 1
		end
	end

	return cleaned
end

-- 定期清理（基于时间间隔）
local _last_cleanup = 0

function M.smart_cleanup()
	local cfg = config.get()
	local now = os.time()

	if (now - _last_cleanup) / 3600 >= cfg.cleanup_interval_hours then
		local cleaned = M.cleanup_all_projects()
		_last_cleanup = now

		if cleaned > 0 then
			vim.notify("json_store: cleaned " .. cleaned .. " items")
		end
	end
end

-- 清理某个文件的引用（在 BufDelete 时调用）
function M.cleanup_file_refs(filepath)
	if not filepath or filepath == "" then
		return 0
	end

	local _, project_obj = project.get_current_project()
	if not project_obj then
		return 0
	end

	local proj_store = ensure_project_store(project_obj)
	if not proj_store then
		return 0
	end

	local proj_data = store.load(proj_store)
	proj_data.file_mappings = proj_data.file_mappings or {}

	local removed = 0

	for file_id, mapping in pairs(proj_data.file_mappings) do
		if mapping.path == filepath then
			-- 删除 file json
			local file_store = project_obj.stores.files and project_obj.stores.files[file_id]
			if file_store and file_store.path then
				pcall(os.remove, file_store.path)
			end
			-- 从内存中移除
			if project_obj.stores.files then
				project_obj.stores.files[file_id] = nil
			end
			-- 从映射中移除
			proj_data.file_mappings[file_id] = nil
			removed = removed + 1
		end
	end

	if removed > 0 then
		store.mark_dirty(proj_store)
	end

	return removed
end

return M
