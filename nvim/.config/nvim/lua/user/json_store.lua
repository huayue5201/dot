local M = {}

-- ========== 模块私有部分 ==========
local _state_store = nil

-- 默认配置
local _default_config = {
	file_path = vim.fn.stdpath("cache") .. "/project_states.json",
	auto_save = true,
	save_delay_ms = 0,
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

-- 确保存储实例已初始化
local function _ensure_store()
	if not _state_store then
		_state_store = _new_instance(_default_config)
	end
	return _state_store
end

-- 项目键生成
local function _project_key()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 读取文件并解析JSON
local function _load_from_file(store)
	local f = io.open(store.file_path, "r")
	if not f then
		return {} -- 文件不存在时返回空表
	end
	local content = f:read("*a")
	f:close()

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	else
		vim.notify("JSON解析失败: " .. store.file_path, vim.log.levels.WARN)
		return {} -- 返回空表
	end
end

-- 加载数据
local function _load(store)
	if not store.data then
		store.data = _load_from_file(store)
	end
	return store.data
end

-- 保存数据到文件
local function _save(store)
	if not store.data then
		return false
	end

	-- 确保目录存在
	local dir = vim.fn.fnamemodify(store.file_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end

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

	-- 写入文件
	local f = io.open(store.file_path, "w")
	if not f then
		vim.notify("无法写入JSON文件: " .. store.file_path, vim.log.levels.ERROR)
		return false
	end
	f:write(json_str)
	f:close()

	store._dirty = false
	return true
end

-- 延迟保存（防抖）
local function _schedule_save(store)
	if not store.auto_save or not store._dirty then
		return
	end

	if _save_timer then
		_save_timer:stop()
	end

	_save_timer = vim.defer_fn(function()
		_save(store)
		_save_timer = nil
	end, store.save_delay)
end

-- ========== 公共API部分 ==========

-- 设置数据
function M.set(namespace, key, value)
	local store = _ensure_store()
	local pkey = _project_key()
	local data = _load(store)

	data[pkey] = data[pkey] or {}
	data[pkey][namespace] = data[pkey][namespace] or {}
	data[pkey][namespace][key] = value

	store.data = data
	store._dirty = true
	_schedule_save(store)
end

-- 获取数据
function M.get(namespace, key)
	local store = _ensure_store()
	local pkey = _project_key()
	local data = _load(store)

	return data[pkey] and data[pkey][namespace] and data[pkey][namespace][key] or nil
end

-- 获取某个 namespace 下的所有数据
function M.get_all(namespace)
	local store = _ensure_store()
	local pkey = _project_key()
	local data = _load(store)

	return data[pkey] and data[pkey][namespace] or {}
end

-- 删除指定数据
function M.delete(namespace, key)
	local store = _ensure_store()
	local pkey = _project_key()
	local data = _load(store)

	if data[pkey] and data[pkey][namespace] and data[pkey][namespace][key] ~= nil then
		data[pkey][namespace][key] = nil
		store.data = data
		store._dirty = true
		_schedule_save(store)
	end
end

-- 清除项目数据
function M.clear_project_data()
	local store = _ensure_store()
	local pkey = _project_key()
	local data = _load(store)

	data[pkey] = nil
	store.data = data
	store._dirty = true
	_schedule_save(store)
end

-- 强制保存数据
function M.save()
	local store = _ensure_store()
	return _save(store)
end

return M
