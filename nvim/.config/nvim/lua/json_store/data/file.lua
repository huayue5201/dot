-- json_store/data/file.lua
local project = require("json_store.core.project")
local store = require("json_store.core.store")
local config = require("json_store.core.config")

local M = {}

----------------------------------------------------------------------
-- 1. 路径过滤
----------------------------------------------------------------------

local function should_ignore_path(path)
	if not path or path == "" then
		return true
	end

	path = vim.fn.fnamemodify(path, ":p")

	-- 根目录
	if path == "/" then
		return true
	end

	-- 从 config 读取 ignore_paths
	local cfg = config.get()
	local ignores = cfg.ignore_paths or {}

	for _, rule in ipairs(ignores) do
		-- 前缀匹配
		if path:sub(1, #rule) == rule then
			return true
		end
		-- 正则匹配
		if path:match(rule) then
			return true
		end
	end

	return false
end

----------------------------------------------------------------------
-- 2. dummy store（避免返回 nil 导致崩溃）
----------------------------------------------------------------------

local function dummy_store(project_obj)
	-- 必须提供一个合法 path，否则 fs_stat(nil) 会崩溃
	return {
		path = project_obj.paths.files_dir .. "/__ignored__.json",
		data = {}, -- 空数据
		mtime = nil,
		dirty = false,
		timer = nil,
		file_id = nil,
		__dummy = true, -- 标记为 dummy
	}
end

----------------------------------------------------------------------
-- 3. file_id 生成
----------------------------------------------------------------------

local function sha256(str)
	return vim.fn.sha256(str)
end

local function file_id_from_path(filepath)
	local full = vim.fn.fnamemodify(filepath, ":p")
	return "file_" .. sha256(full):sub(1, 16)
end

----------------------------------------------------------------------
-- 4. 主函数：获取文件 store
----------------------------------------------------------------------

function M.get_file_store(project_obj, filepath)
	-- ★ 路径过滤：返回 dummy store，而不是 nil
	if should_ignore_path(filepath) then
		return dummy_store(project_obj), nil
	end

	local file_id = file_id_from_path(filepath)

	-- 创建 file store
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

		-- project.json
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

		-- 写入 file_mappings
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
