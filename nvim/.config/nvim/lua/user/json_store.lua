-- user/json_store.lua (优化版本)
local M = {}

-- ================== 默认配置 ==================

local _default_config = {
	root_markers = { ".git", ".hg", ".svn", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" },
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v5/",
	auto_save = true,
	save_delay_ms = 1500,
	cleanup_strategy = "conservative",
	max_cache_age = 7200,
	max_projects = 10,
	global_namespaces = {}, -- 全局命名空间，不受项目切换影响

	-- 新增清理配置
	cleanup_on_startup = true,
	cleanup_on_project_switch = true,
	cleanup_interval_hours = 24, -- 定期清理间隔（小时）
	max_file_check_per_run = 100, -- 每次清理最大文件检查数量
}

-- ================== 内部状态 ==================

local _projects = {} -- [project_key] = { root, paths = {...}, stores = {...} }
local _config = vim.deepcopy(_default_config)
local _global_project = nil -- 全局项目存储
local _cleanup_cache = {} -- 文件存在性检查缓存
local _last_cleanup_time = 0 -- 上次清理时间

-- ================== 工具函数 ==================

local function _ensure_dir(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

local function _join(...)
	return table.concat({ ... }, "/")
end

local function _sha256(str)
	return vim.fn.sha256(str)
end

local function _file_exists(path)
	-- 使用缓存提高性能
	if _cleanup_cache[path] ~= nil then
		return _cleanup_cache[path]
	end

	local exists = vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
	_cleanup_cache[path] = exists
	return exists
end

local function _get_mtime(path)
	local stat = vim.loop.fs_stat(path)
	return stat and stat.mtime and stat.mtime.sec or nil
end

-- ================== 性能优化：批量操作 ==================

local function _batch_file_exists_check(paths)
	local results = {}
	for _, path in ipairs(paths) do
		if _cleanup_cache[path] == nil then
			results[path] = vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
		else
			results[path] = _cleanup_cache[path]
		end
	end

	-- 更新缓存
	for path, exists in pairs(results) do
		_cleanup_cache[path] = exists
	end

	return results
end

-- ================== 项目识别 ==================

local function _find_project_root(filepath)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	if filepath == "" then
		return vim.loop.cwd()
	end

	local dir = vim.fn.fnamemodify(filepath, ":p:h")
	local prev = nil

	while dir and dir ~= prev do
		for _, marker in ipairs(_config.root_markers) do
			if _file_exists(_join(dir, marker)) then
				return dir
			end
		end
		prev = dir
		dir = vim.fn.fnamemodify(dir, ":h")
	end

	return vim.loop.cwd()
end

local function _get_project_key(root)
	local project_name = vim.fn.fnamemodify(root, ":t")
	local hash = _sha256(root):sub(1, 8)
	return (project_name .. "_" .. hash):gsub("[^%w_%-]", "_")
end

local function _ensure_project(root, is_global)
	if is_global then
		-- 全局项目
		if _global_project then
			return "global", _global_project
		end

		local base = _join(_config.cache_root, "global")
		local project = {
			root = "global",
			key = "global",
			base = base,
			paths = {
				project = _join(base, "project.json"),
				namespaces_dir = _join(base, "namespaces"),
				files_dir = _join(base, "files"),
			},
			stores = {
				project = nil,
				namespaces = {},
				files = {},
				notes = {},
			},
			last_access = os.time(),
			is_global = true,
		}

		_ensure_dir(base)
		_ensure_dir(project.paths.namespaces_dir)
		_ensure_dir(project.paths.files_dir)

		_global_project = project
		return "global", project
	else
		-- 普通项目
		local key = _get_project_key(root)
		if _projects[key] then
			_projects[key].last_access = os.time()
			return key, _projects[key]
		end

		-- 项目数量限制检查
		if #_projects >= _config.max_projects then
			M.cleanup_stale_projects(_config.max_cache_age * 0.5) -- 清理较旧的项目
		end

		local base = _join(_config.cache_root, key)
		local project = {
			root = root,
			key = key,
			base = base,
			paths = {
				project = _join(base, "project.json"),
				namespaces_dir = _join(base, "namespaces"),
				files_dir = _join(base, "files"),
			},
			stores = {
				project = nil,
				namespaces = {},
				files = {},
				notes = {},
			},
			last_access = os.time(),
			is_global = false,
		}

		_ensure_dir(base)
		_ensure_dir(project.paths.namespaces_dir)
		_ensure_dir(project.paths.files_dir)

		_projects[key] = project
		return key, project
	end
end

-- ================== 优化文件ID生成（方案3）==================

local function _file_id_from_path(filepath)
	-- 使用绝对路径的哈希，避免重命名导致的ID变化
	local full_path = vim.fn.fnamemodify(filepath, ":p")
	local hash = _sha256(full_path):sub(1, 16)
	return "file_" .. hash
end

-- 反向查找：从file_id获取原始文件路径（存储在项目元数据中）
local function _store_file_mapping(project, file_id, filepath)
	local store = _get_project_store(project)
	local data = _load_store(store)
	data.file_mappings = data.file_mappings or {}
	data.file_mappings[file_id] = {
		path = vim.fn.fnamemodify(filepath, ":p"),
		last_accessed = os.time(),
	}
	_mark_dirty(store)
end

local function _get_file_path_from_id(project, file_id)
	local store = _get_project_store(project)
	local data = _load_store(store)
	if data.file_mappings and data.file_mappings[file_id] then
		return data.file_mappings[file_id].path
	end
	return nil
end

-- ================== 通用 store 结构 ==================

local function _load_store(store)
	if store.data ~= nil then
		local mtime = _get_mtime(store.path)
		if mtime and store.mtime and mtime == store.mtime then
			return store.data
		end
	end

	if not _file_exists(store.path) then
		store.data = {}
		store.mtime = nil
		return store.data
	end

	local ok, content = pcall(vim.fn.readfile, store.path)
	if not ok or not content then
		store.data = {}
		store.mtime = _get_mtime(store.path)
		return store.data
	end

	local json = table.concat(content, "\n")
	local ok2, decoded = pcall(vim.json.decode, json)
	if not ok2 or type(decoded) ~= "table" then
		store.data = {}
	else
		store.data = decoded
	end
	store.mtime = _get_mtime(store.path)
	return store.data
end

local function _write_store(store)
	if not store.data then
		return
	end
	local ok, json = pcall(vim.json.encode, store.data, { indent = "  ", sort_keys = true })
	if not ok then
		return
	end
	local ok2 = pcall(vim.fn.writefile, vim.split(json, "\n"), store.path)
	if not ok2 then
		return
	end
	store.dirty = false
	store.mtime = _get_mtime(store.path)
end

local function _schedule_store_save(store)
	if not _config.auto_save then
		return
	end
	if store.timer then
		store.timer:stop()
		store.timer:close()
		store.timer = nil
	end

	local delay = _config.save_delay_ms
	local timer = vim.loop.new_timer()
	store.timer = timer
	timer:start(delay, 0, function()
		vim.schedule(function()
			_write_store(store)
		end)
		timer:stop()
		timer:close()
		store.timer = nil
	end)
end

local function _mark_dirty(store)
	store.dirty = true
	_schedule_store_save(store)
end

-- ================== 获取具体 store ==================

local function _get_project_store(project)
	if not project.stores.project then
		project.stores.project = {
			path = project.paths.project,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
		}
	end
	return project.stores.project
end

local function _get_namespace_store(project, namespace)
	if not project.stores.namespaces[namespace] then
		local path = _join(project.paths.namespaces_dir, namespace .. ".json")
		project.stores.namespaces[namespace] = {
			path = path,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
		}
	end
	return project.stores.namespaces[namespace]
end

local function _get_file_store(project, filepath)
	local file_id = _file_id_from_path(filepath)
	if not project.stores.files[file_id] then
		local path = _join(project.paths.files_dir, file_id .. ".json")
		local store = {
			path = path,
			data = nil,
			mtime = nil,
			dirty = false,
			timer = nil,
			file_id = file_id,
		}
		project.stores.files[file_id] = store

		-- 记录文件映射
		_store_file_mapping(project, file_id, filepath)
	end
	return project.stores.files[file_id], file_id
end

-- ================== 清理无效数据（核心优化）==================

-- 方案1：定期清理无效文件引用（带性能优化）
function M.cleanup_invalid_file_refs(project, limit)
	limit = limit or _config.max_file_check_per_run
	local cleaned = 0
	local checked = 0

	-- 清理文件存储
	local file_ids_to_check = {}
	local file_id_to_path = {}

	for file_id, store in pairs(project.stores.files) do
		if checked >= limit then
			break
		end

		-- 获取文件路径
		local filepath = _get_file_path_from_id(project, file_id)
		if filepath then
			table.insert(file_ids_to_check, file_id)
			file_id_to_path[file_id] = filepath
			checked = checked + 1
		end
	end

	-- 批量检查文件存在性
	local paths_to_check = {}
	for _, path in pairs(file_id_to_path) do
		table.insert(paths_to_check, path)
	end

	local existence_results = _batch_file_exists_check(paths_to_check)

	-- 清理不存在的文件
	for file_id, store in pairs(project.stores.files) do
		local filepath = file_id_to_path[file_id]
		if filepath and not existence_results[filepath] then
			-- 删除文件存储
			if store.timer then
				store.timer:stop()
				store.timer:close()
			end
			os.remove(store.path)
			project.stores.files[file_id] = nil
			cleaned = cleaned + 1
		end
	end

	-- 清理命名空间中的无效引用
	for namespace, store in pairs(project.stores.namespaces) do
		local data = _load_store(store)
		local changed = false

		for key, value in pairs(data) do
			if type(value) == "table" then
				-- 检查所有文件引用
				for file_ref, _ in pairs(value) do
					local filepath = _get_file_path_from_id(project, file_ref)
					if filepath and not _file_exists(filepath) then
						value[file_ref] = nil
						changed = true
						cleaned = cleaned + 1
					end
				end
			end
		end

		if changed then
			_mark_dirty(store)
		end
	end

	-- 更新文件映射，移除无效映射
	local proj_store = _get_project_store(project)
	local proj_data = _load_store(proj_store)
	if proj_data.file_mappings then
		local changed = false
		for file_id, mapping in pairs(proj_data.file_mappings) do
			if not _file_exists(mapping.path) then
				proj_data.file_mappings[file_id] = nil
				changed = true
			end
		end
		if changed then
			_mark_dirty(proj_store)
		end
	end

	-- 清理缓存
	for filepath, _ in pairs(existence_results) do
		_cleanup_cache[filepath] = nil
	end

	return cleaned
end

-- 方案2：文件监控清理
local _watched_files = {}

local function _setup_file_watcher(filepath, callback)
	if _watched_files[filepath] then
		return
	end

	-- 使用uv文件监控
	local function watch_cb(err, filename, events)
		if err then
			return
		end

		if events.change then
			-- 文件内容变化
			_cleanup_cache[filepath] = nil -- 清除缓存
		end

		if events.rename then
			-- 文件重命名或删除
			vim.schedule(function()
				callback(filepath)
			end)
		end
	end

	local fs_event = vim.loop.new_fs_event()
	fs_event:start(filepath, {}, vim.schedule_wrap(watch_cb))

	_watched_files[filepath] = {
		fs_event = fs_event,
		callback = callback,
	}
end

function M.cleanup_file_refs(filepath)
	local file_id = _file_id_from_path(filepath)
	local cleaned = 0

	-- 清理所有项目中的引用
	for _, project in pairs(_projects) do
		-- 检查文件是否属于该项目
		local filepath_in_project = _get_file_path_from_id(project, file_id)
		if filepath_in_project and not _file_exists(filepath_in_project) then
			-- 清理文件存储
			if project.stores.files[file_id] then
				local store = project.stores.files[file_id]
				if store.timer then
					store.timer:stop()
					store.timer:close()
				end
				os.remove(store.path)
				project.stores.files[file_id] = nil
				cleaned = cleaned + 1
			end

			-- 清理命名空间中的引用
			for namespace, ns_store in pairs(project.stores.namespaces) do
				local data = _load_store(ns_store)
				local changed = false

				for key, value in pairs(data) do
					if type(value) == "table" and value[file_id] ~= nil then
						value[file_id] = nil
						changed = true
						cleaned = cleaned + 1
					end
				end

				if changed then
					_mark_dirty(ns_store)
				end
			end
		end
	end

	return cleaned
end

-- 方案4：全局清理命令（带分页和性能控制）
-- 安全的glob函数，确保返回表
local function _safe_glob(pattern, use_list)
	use_list = use_list == nil and true or use_list
	local result = vim.fn.glob(pattern, use_list)

	if type(result) == "string" then
		if result == "" then
			return {}
		else
			-- 分割换行符
			return vim.split(result, "\n")
		end
	elseif type(result) == "table" then
		return result
	else
		return {}
	end
end

-- 然后在cleanup_all_projects中使用：
function M.cleanup_all_projects(options)
	options = options or {}
	local limit_per_project = options.limit_per_project or _config.max_file_check_per_run
	local skip_recent = options.skip_recent or 3600 -- 跳过最近1小时内访问的

	local total_cleaned = 0
	local now = os.time()

	-- 清理全局项目
	if _global_project then
		if now - (_global_project.last_access or 0) > skip_recent then
			total_cleaned = total_cleaned + M.cleanup_invalid_file_refs(_global_project, limit_per_project)
		end
	end

	-- 清理所有普通项目
	for project_key, project in pairs(_projects) do
		if now - (project.last_access or 0) > skip_recent then
			total_cleaned = total_cleaned + M.cleanup_invalid_file_refs(project, limit_per_project)
		end
	end

	-- 清理孤儿文件（没有映射的文件存储）
	for project_key, project in pairs(_projects) do
		local orphan_cleaned = 0
		local file_dir = project.paths.files_dir

		-- 使用安全的glob函数
		local files = _safe_glob(file_dir .. "/*.json", true)

		-- 遍历文件
		for _, file in ipairs(files) do
			if file and file ~= "" then
				local file_id = vim.fn.fnamemodify(file, ":t:r")
				if not _get_file_path_from_id(project, file_id) then
					-- 没有映射的文件，删除
					pcall(os.remove, file) -- 使用pcall防止删除失败
					if project.stores.files[file_id] then
						project.stores.files[file_id] = nil
					end
					orphan_cleaned = orphan_cleaned + 1
				end
			end
		end

		total_cleaned = total_cleaned + orphan_cleaned
	end

	-- 重置缓存
	_cleanup_cache = {}

	return total_cleaned
end

-- 智能定期清理
function M.smart_cleanup()
	local now = os.time()
	local hours_since_last_cleanup = (now - _last_cleanup_time) / 3600

	if hours_since_last_cleanup >= _config.cleanup_interval_hours then
		local cleaned = M.cleanup_all_projects({
			limit_per_project = _config.max_file_check_per_run,
			skip_recent = 1800, -- 跳过最近30分钟访问的
		})
		_last_cleanup_time = now

		if cleaned > 0 then
			vim.notify(string.format("Cleaned up %d invalid file references", cleaned), vim.log.levels.INFO)
		end
	end
end
-- ================== 公共 API：配置 ==================

function M.setup(opts)
	_config = vim.tbl_deep_extend("force", _config, opts or {})
	_ensure_dir(_config.cache_root)
	_ensure_dir(_join(_config.cache_root, "global"))

	-- 启动时清理
	if _config.cleanup_on_startup then
		vim.defer_fn(function()
			M.smart_cleanup()
		end, 5000) -- 延迟5秒执行，避免影响启动性能
	end
end

-- ================== 公共 API：项目信息 ==================

function M.get_current_project()
	local root = _find_project_root()
	local key, project = _ensure_project(root)

	-- 项目切换时清理
	if _config.cleanup_on_project_switch and project.last_access then
		local now = os.time()
		if now - project.last_access > 3600 then -- 超过1小时未访问
			M.cleanup_invalid_file_refs(project, 20) -- 有限清理
		end
	end

	return {
		key = key,
		root = root,
		base = project.base,
		project_file = project.paths.project,
	}
end

function M.get_current_project_file()
	local info = M.get_current_project()
	return info.project_file
end

-- ================== 核心：命名空间操作（支持全局模式）==================

local function _with_namespace(namespace, fn, use_global)
	local project_key, project

	if use_global then
		-- 使用全局存储
		project_key, project = _ensure_project("global", true)
	else
		-- 自动检测：如果命名空间在全局列表中，使用全局存储
		if vim.tbl_contains(_config.global_namespaces or {}, namespace) then
			project_key, project = _ensure_project("global", true)
		else
			-- 使用项目存储
			local root = _find_project_root()
			project_key, project = _ensure_project(root)
		end
	end

	local store = _get_namespace_store(project, namespace)
	local data = _load_store(store)
	local changed = fn(data)
	if changed then
		_mark_dirty(store)
	end
end

function M.set(namespace, key, value, file_id, use_global)
	use_global = use_global or false
	_with_namespace(namespace, function(ns)
		ns[key] = ns[key] or {}
		if file_id ~= nil then
			ns[key][file_id] = value
		else
			ns[key] = value
		end
		return true
	end, use_global)
end

function M.get(namespace, key, file_id, use_global)
	use_global = use_global or false

	-- 如果是TODO链接，先在全局查找，再在项目中查找
	if not use_global and (namespace == "todo_links" or namespace == "code_links") then
		-- 先查全局
		local root = _find_project_root()
		local global_key, global_project = _ensure_project("global", true)
		local store = _get_namespace_store(global_project, namespace)
		local global_data = _load_store(store)

		if global_data[key] then
			local v = global_data[key]
			if file_id ~= nil and type(v) == "table" then
				return v[file_id]
			end
			return v
		end
	end

	-- 正常查找
	local project_key, project
	if use_global then
		project_key, project = _ensure_project("global", true)
	elseif vim.tbl_contains(_config.global_namespaces or {}, namespace) then
		project_key, project = _ensure_project("global", true)
	else
		local root = _find_project_root()
		project_key, project = _ensure_project(root)
	end

	local store = _get_namespace_store(project, namespace)
	local data = _load_store(store)
	local v = data[key]
	if file_id ~= nil and type(v) == "table" then
		return v[file_id]
	end
	return v
end

function M.delete(namespace, key, file_id, use_global)
	use_global = use_global or false
	_with_namespace(namespace, function(ns)
		local v = ns[key]
		if not v then
			return false
		end
		if file_id ~= nil and type(v) == "table" then
			v[file_id] = nil
			if vim.tbl_isempty(v) then
				ns[key] = nil
			end
		else
			ns[key] = nil
		end
		return true
	end, use_global)
end

function M.get_all(namespace, use_global)
	use_global = use_global or false

	local project_key, project
	if use_global then
		project_key, project = _ensure_project("global", true)
	elseif vim.tbl_contains(_config.global_namespaces or {}, namespace) then
		project_key, project = _ensure_project("global", true)
	else
		local root = _find_project_root()
		project_key, project = _ensure_project(root)
	end

	local store = _get_namespace_store(project, namespace)
	local data = _load_store(store)
	return data
end

-- ================== 双链笔记专用 API ==================

-- 查找所有项目中的链接（向后兼容）
function M.find_in_all_projects(namespace, key)
	-- 先查全局
	local _, global_project = _ensure_project("global", true)
	local global_store = _get_namespace_store(global_project, namespace)
	local global_data = _load_store(global_store)

	if global_data[key] then
		return global_data[key], "global"
	end

	-- 再查所有项目
	for project_key, project in pairs(_projects) do
		local store = _get_namespace_store(project, namespace)
		local data = _load_store(store)
		if data[key] then
			return data[key], project_key
		end
	end

	return nil
end

-- 获取所有项目中的所有链接（用于搜索）
function M.get_all_in_namespace(namespace)
	local results = {}

	-- 获取全局数据
	local _, global_project = _ensure_project("global", true)
	local global_store = _get_namespace_store(global_project, namespace)
	local global_data = _load_store(global_store)

	for key, value in pairs(global_data) do
		results[key] = {
			value = value,
			project = "global",
		}
	end

	-- 获取所有项目数据
	for project_key, project in pairs(_projects) do
		local store = _get_namespace_store(project, namespace)
		local data = _load_store(store)
		for key, value in pairs(data) do
			results[key] = {
				value = value,
				project = project_key,
			}
		end
	end

	return results
end

-- 清理无效链接
function M.cleanup_namespace(namespace, check_func)
	local cleaned = 0

	-- 清理全局
	local _, global_project = _ensure_project("global", true)
	local global_store = _get_namespace_store(global_project, namespace)
	local global_data = _load_store(global_store)
	local global_changed = false

	for key, value in pairs(global_data) do
		if not check_func(key, value, "global") then
			global_data[key] = nil
			global_changed = true
			cleaned = cleaned + 1
		end
	end

	if global_changed then
		_mark_dirty(global_store)
	end

	-- 清理所有项目
	for project_key, project in pairs(_projects) do
		local store = _get_namespace_store(project, namespace)
		local data = _load_store(store)
		local changed = false

		for key, value in pairs(data) do
			if not check_func(key, value, project_key) then
				data[key] = nil
				changed = true
				cleaned = cleaned + 1
			end
		end

		if changed then
			_mark_dirty(store)
		end
	end

	return cleaned
end

-- ================== 公共 API：行级数据 ==================

function M.set_line_data(filepath, line, data)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	local root = _find_project_root(filepath)
	local _, project = _ensure_project(root)
	local store, file_id = _get_file_store(project, filepath)
	local file_data = _load_store(store)

	file_data.lines = file_data.lines or {}
	file_data.lines[tostring(line)] = data
	file_data.filepath = filepath -- 确保存储文件路径

	_mark_dirty(store)
end

function M.get_line_data(filepath, line)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	local root = _find_project_root(filepath)
	local _, project = _ensure_project(root)
	local store = _get_file_store(project, filepath)
	local file_data = _load_store(store)

	local lines = file_data.lines or {}
	return lines[tostring(line)]
end

-- ================== 公共 API：保存 ==================

function M.save_all()
	-- 保存全局项目
	if _global_project then
		if _global_project.stores.project then
			_write_store(_global_project.stores.project)
		end
		for _, store in pairs(_global_project.stores.namespaces) do
			_write_store(store)
		end
		for _, store in pairs(_global_project.stores.files) do
			_write_store(store)
		end
	end

	-- 保存所有项目
	for _, project in pairs(_projects) do
		if project.stores.project then
			_write_store(project.stores.project)
		end
		for _, store in pairs(project.stores.namespaces) do
			_write_store(store)
		end
		for _, store in pairs(project.stores.files) do
			_write_store(store)
		end
	end
end

-- ================== 缓存清理 ==================

function M.cleanup_stale_projects(max_age_seconds)
	max_age_seconds = max_age_seconds or _config.max_cache_age
	local now = os.time()
	local cleaned = 0

	for key, project in pairs(_projects) do
		if project.is_global then
			-- 不清理全局项目
			goto continue
		end

		local age = now - (project.last_access or 0)
		if age > max_age_seconds then
			-- 先清理无效引用
			M.cleanup_invalid_file_refs(project, 50)

			-- 保存脏数据
			if project.stores.project and project.stores.project.dirty then
				_write_store(project.stores.project)
			end

			for _, store in pairs(project.stores.namespaces) do
				if store.dirty then
					_write_store(store)
				end
			end

			for _, store in pairs(project.stores.files) do
				if store.dirty then
					_write_store(store)
				end
			end

			-- 清理定时器
			for _, store in pairs(project.stores.namespaces) do
				if store.timer then
					store.timer:stop()
					store.timer:close()
				end
			end

			for _, store in pairs(project.stores.files) do
				if store.timer then
					store.timer:stop()
					store.timer:close()
				end
			end

			_projects[key] = nil
			cleaned = cleaned + 1
		end

		::continue::
	end

	return cleaned
end

-- ================== 新增API：状态报告 ==================

function M.get_stats()
	local stats = {
		projects = 0,
		global_files = 0,
		total_files = 0,
		namespaces = 0,
		cache_size = 0,
	}

	-- 项目统计
	stats.projects = #_projects
	if _global_project then
		stats.projects = stats.projects + 1
	end

	-- 文件存储统计
	for _, project in pairs(_projects) do
		stats.total_files = stats.total_files + #project.stores.files
		stats.namespaces = stats.namespaces + #project.stores.namespaces
	end

	if _global_project then
		stats.global_files = #_global_project.stores.files
		stats.total_files = stats.total_files + stats.global_files
		stats.namespaces = stats.namespaces + #_global_project.stores.namespaces
	end

	-- 缓存统计
	stats.cache_hits = 0
	for _, exists in pairs(_cleanup_cache) do
		stats.cache_hits = stats.cache_hits + 1
	end

	return stats
end

-- ================== 自动事件设置 ==================

local function _setup_autocmds()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("JsonStoreV5", { clear = true }),
		callback = function()
			M.save_all()
			-- 退出时执行快速清理
			M.cleanup_all_projects({
				limit_per_project = 10,
				skip_recent = 300, -- 跳过最近5分钟访问的
			})
		end,
	})

	vim.api.nvim_create_autocmd("DirChanged", {
		group = vim.api.nvim_create_augroup("JsonStoreV5DirChanged", { clear = true }),
		callback = function()
			M.cleanup_stale_projects()
			M.smart_cleanup()
		end,
	})

	vim.api.nvim_create_autocmd("BufDelete", {
		group = vim.api.nvim_create_augroup("JsonStoreV5BufDelete", { clear = true }),
		callback = function(args)
			local filepath = vim.api.nvim_buf_get_name(args.buf)
			if filepath ~= "" then
				M.cleanup_file_refs(filepath)
			end
		end,
	})

	-- 定期清理
	local timer = vim.loop.new_timer()
	timer:start(
		3600000,
		3600000,
		vim.schedule_wrap(function() -- 每小时检查一次
			M.smart_cleanup()
		end)
	)
end

_setup_autocmds()

return M
