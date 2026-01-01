-- json_store/data/file.lua
local project = require("json_store.core.project")
local store = require("json_store.core.store")

local M = {}

local function sha256(str)
	return vim.fn.sha256(str)
end

local function file_id_from_path(filepath)
	local full = vim.fn.fnamemodify(filepath, ":p")
	return "file_" .. sha256(full):sub(1, 16)
end

function M.get_file_store(project_obj, filepath)
	local file_id = file_id_from_path(filepath)

	if not project_obj.stores.files[file_id] then
		local path = project_obj.paths.files_dir .. "/" .. file_id .. ".json"
		project_obj.stores.files[file_id] = {
			path = path,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
			file_id = file_id,
		}

		-- 写入 file_mappings
		local proj_store = project_obj.stores.project
		if not proj_store then
			proj_store = {
				path = project_obj.paths.project,
				data = nil,
				mtime = nil,
				dirty = false,
			}
			project_obj.stores.project = proj_store
		end

		local data = store.load(proj_store)
		data.file_mappings = data.file_mappings or {}
		data.file_mappings[file_id] = {
			path = filepath,
			last_accessed = os.time(),
		}
		store.mark_dirty(proj_store)
	end

	return project_obj.stores.files[file_id], file_id
end

return M
