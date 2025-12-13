local M = {}

-- ========== 模块私有部分 ==========
local _state_store = nil

-- 默认配置
local _default_config = {
	file_path = vim.fn.stdpath("cache") .. "/project_states/",
	auto_save = true,
	save_delay_ms = 3000,
}

-- 保存定时器（防抖）
local _save_timer = nil

-- 创建新实例
local function _new_instance(config)
	return {
		file_path = config.file_path,
		data = nil,
		_dirty = false,
		auto_save = config.auto_save,
		save_delay = config.save_delay_ms,
	}
end

-- 清理项目名称：移除特殊字符，限制长度
local function _sanitize_project_name(name)
	-- 移除路径分隔符，只保留项目目录名
	local basename = vim.fn.fnamemodify(name, ":t")

	-- 移除特殊字符，只保留字母、数字、下划线、连字符
	basename = basename:gsub("[^%w%-_]", "_")

	-- 限制长度（比如最多30个字符）
	if #basename > 30 then
		basename = basename:sub(1, 30)
	end

	-- 如果清理后为空，使用默认名称
	if #basename == 0 then
		basename = "project"
	end

	return basename
end

-- 获取项目标识：项目名称_哈希值
local function _get_project_key()
	local cwd = vim.fn.getcwd()

	-- 获取项目名称（使用目录名）
	local project_name = _sanitize_project_name(cwd)

	-- 获取哈希值（取前8位通常就够了）
	local hash = vim.fn.sha256(cwd):sub(1, 8)

	-- 组合：项目名称_哈希值
	return string.format("%s_%s", project_name, hash)
end

-- 确保存储实例已初始化
local function _ensure_store()
	if not _state_store then
		_state_store = _new_instance(_default_config)
	end
	return _state_store
end

-- 读取文件并解析JSON
local function _load_from_file(store, project_key)
	local file_path = store.file_path .. project_key .. ".json"
	local f = io.open(file_path, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	else
		vim.notify("JSON解析失败: " .. file_path, vim.log.levels.WARN)
		return {}
	end
end

-- 加载数据
local function _load(store, project_key)
	if not store.data then
		store.data = _load_from_file(store, project_key)
	end
	return store.data
end

-- 确保目录存在
local function _ensure_directory_exists(file_path)
	local dir = vim.fn.fnamemodify(file_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end
end

-- 保存数据到文件
local function _save(store, project_key)
	if not store.data then
		return false
	end

	local file_path = store.file_path .. project_key .. ".json"
	_ensure_directory_exists(file_path)

	local json_str
	local encode_ok, encode_result = pcall(function()
		return vim.json.encode(store.data, { indent = "  ", sort_keys = true })
	end)

	if encode_ok and encode_result then
		json_str = encode_result
	else
		vim.notify("JSON编码失败: " .. (encode_result or "未知错误"), vim.log.levels.WARN)
		json_str = vim.fn.json_encode(store.data)
		json_str = json_str:gsub("{", "{\n  "):gsub("}", "\n}"):gsub(',"', ',\n  "')
	end

	local f = io.open(file_path, "w")
	if not f then
		vim.notify("无法写入JSON文件: " .. file_path, vim.log.levels.ERROR)
		return false
	end
	f:write(json_str)
	f:close()

	store._dirty = false
	return true
end

-- 延迟保存（防抖）
local function _schedule_save(store, project_key)
	if not store.auto_save or not store._dirty then
		return
	end

	if _save_timer then
		_save_timer:stop()
	end

	_save_timer = vim.defer_fn(function()
		_save(store, project_key)
		_save_timer = nil
	end, store.save_delay)
end

-- ========== 公共API部分 ==========

-- 设置数据
function M.set(namespace, key, value)
	local store = _ensure_store()
	local project_key = _get_project_key()
	local data = _load(store, project_key)

	data[namespace] = data[namespace] or {}
	data[namespace][key] = value

	store.data = data
	store._dirty = true
	_schedule_save(store, project_key)
end

-- 获取数据
function M.get(namespace, key)
	local store = _ensure_store()
	local project_key = _get_project_key()
	local data = _load(store, project_key)

	return data[namespace] and data[namespace][key] or nil
end

-- 获取某个 namespace 下的所有数据
function M.get_all(namespace)
	local store = _ensure_store()
	local project_key = _get_project_key()
	local data = _load(store, project_key)

	return data[namespace] or {}
end

-- 删除指定数据
function M.delete(namespace, key)
	local store = _ensure_store()
	local project_key = _get_project_key()
	local data = _load(store, project_key)

	if data[namespace] and data[namespace][key] ~= nil then
		data[namespace][key] = nil
		store.data = data
		store._dirty = true
		_schedule_save(store, project_key)
	end
end

-- 清除当前项目数据
function M.clear_project_data()
	local store = _ensure_store()
	local project_key = _get_project_key()
	local data = _load(store, project_key)

	data = {}
	store.data = data
	store._dirty = true
	_schedule_save(store, project_key)
end

-- 强制保存数据
function M.save()
	local store = _ensure_store()
	local project_key = _get_project_key()
	return _save(store, project_key)
end

-- 获取当前项目的文件路径（调试用）
function M.get_current_project_file()
	local store = _ensure_store()
	local project_key = _get_project_key()
	return store.file_path .. project_key .. ".json"
end

-- 获取当前项目的标识符（调试用）
function M.get_current_project_key()
	return _get_project_key()
end

return M
