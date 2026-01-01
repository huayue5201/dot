-- json_store/maintenance/cleanup.lua
local project = require("json_store.core.project")
local store = require("json_store.core.store")

local M = {}

local function file_exists(path)
	return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

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

function M.cleanup_invalid_file_refs(project_obj)
	if not project_obj or not project_obj.paths then
		return 0
	end

	local cleaned = 0

	local proj_store = ensure_project_store(project_obj)
	if not proj_store then
		return 0
	end

	local proj_data = store.load(proj_store)
	proj_data.file_mappings = proj_data.file_mappings or {}

	for file_id, mapping in pairs(proj_data.file_mappings) do
		if not file_exists(mapping.path) then
			local file_store = project_obj.stores.files[file_id]
			if file_store and file_store.path then
				pcall(os.remove, file_store.path)
			end
			project_obj.stores.files[file_id] = nil
			proj_data.file_mappings[file_id] = nil
			cleaned = cleaned + 1
		end
	end

	if cleaned > 0 then
		store.mark_dirty(proj_store)
	end

	return cleaned
end

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

function M.cleanup_all_projects()
	local total = 0

	local _, global_project = project.ensure_project("global", true)
	total = total + M.cleanup_invalid_file_refs(global_project)
	total = total + cleanup_orphan_files(global_project)

	for _, project_obj in pairs(project.get_all_projects() or {}) do
		total = total + M.cleanup_invalid_file_refs(project_obj)
		total = total + cleanup_orphan_files(project_obj)
	end

	return total
end

return M
