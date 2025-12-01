-- lua/user/json_store.lua
local M = {}

-- ========== 模块私有部分 ==========
local _state_store = nil
local _default_config = {
	file_path = vim.fn.stdpath("cache") .. "/project_states.json",
	default_data = {},
	auto_save = true,
}

-- 内部方法：确保存储实例已初始化
local function _ensure_store()
	if not _state_store then
		_state_store = M:_new_instance(_default_config)
	end
	return _state_store
end

-- 内部方法：创建新实例
function M:_new_instance(config)
	local instance = {
		file_path = config.file_path,
		default_data = config.default_data or {},
		data = nil,
		_dirty = false,
		auto_save = config.auto_save or false,
	}
	setmetatable(instance, { __index = self })
	return instance
end

-- 核心：项目键生成（所有模块共享）
function M:_project_key()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 基础存储方法
function M:_load_from_file()
	local f = io.open(self.file_path, "r")
	if not f then
		return vim.deepcopy(self.default_data)
	end
	local content = f:read("*a")
	f:close()

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	else
		vim.notify("JSON解析失败,使用默认数据: " .. self.file_path, vim.log.levels.WARN)
		return vim.deepcopy(self.default_data)
	end
end

function M:load()
	if not self.data then
		self.data = self:_load_from_file()
	end
	return self.data
end

-- 修改 json_store.lua 中的 save 函数
function M:save()
	if not self.data then
		return false
	end

	-- 确保目录存在
	local dir = vim.fn.fnamemodify(self.file_path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end

	local json_str
	local encode_ok, encode_result = pcall(function()
		-- 使用 vim.json.encode 进行美化格式化
		return vim.json.encode(self.data, {
			indent = "  ", -- 使用两个空格缩进
			sort_keys = true, -- 可选：按键名排序，使输出更一致
		})
	end)

	if encode_ok and encode_result then
		json_str = encode_result
	else
		-- 回退方案：使用 vim.fn.json_encode 并简单美化
		vim.notify(
			"vim.json.encode 失败，使用回退方案: " .. (encode_result or "未知错误"),
			vim.log.levels.WARN
		)
		json_str = vim.fn.json_encode(self.data)
		-- 简单美化
		json_str = json_str:gsub("{", "{\n  "):gsub("}", "\n}"):gsub(',"', ',\n  "')
	end

	local f = io.open(self.file_path, "w")
	if not f then
		vim.notify("无法写入JSON文件: " .. self.file_path, vim.log.levels.ERROR)
		return false
	end
	f:write(json_str)
	f:close()

	self._dirty = false
	return true
end

-- 修改 json_store.lua 中的 save 函数
-- ========== 公共API部分 ==========

-- 1. 基础通用API（适合任何模块）
function M.set(namespace, key, value)
	local store = _ensure_store()
	local pkey = store:_project_key()
	local data = store:load()

	-- 确保数据结构存在
	if not data[pkey] then
		data[pkey] = {}
	end
	if not data[pkey][namespace] then
		data[pkey][namespace] = {}
	end

	data[pkey][namespace][key] = value

	store.data = data
	store._dirty = true
	if store.auto_save then
		store:save()
	end
end

function M.get(namespace, key)
	local store = _ensure_store()
	local pkey = store:_project_key()
	local data = store:load()

	if data[pkey] and data[pkey][namespace] then
		return data[pkey][namespace][key]
	end
	return nil
end

function M.get_all(namespace)
	local store = _ensure_store()
	local pkey = store:_project_key()
	local data = store:load()

	if data[pkey] and data[pkey][namespace] then
		return data[pkey][namespace]
	end
	return {}
end

function M.delete(namespace, key)
	local store = _ensure_store()
	local pkey = store:_project_key()
	local data = store:load()

	if data[pkey] and data[pkey][namespace] then
		if data[pkey][namespace][key] ~= nil then
			data[pkey][namespace][key] = nil
			store.data = data
			store._dirty = true
			if store.auto_save then
				store:save()
			end
		end
	end
end

-- 2. 模块专用API（为env模块封装）
function M.set_env(env_name)
	return M.set("env", "selected", env_name)
end

function M.get_env()
	return M.get("env", "selected")
end

function M.clear_env()
	M.delete("env", "selected")
end

-- 3. LSP专用API（示例）
function M.set_lsp_state(server_name, state)
	return M.set("lsp", server_name, state)
end

function M.get_lsp_state(server_name)
	return M.get("lsp", server_name)
end

function M.get_all_lsp_states()
	return M.get_all("lsp")
end

-- 4. 插件专用API（示例）
function M.set_plugin_state(plugin_name, state)
	return M.set("plugins", plugin_name, state)
end

function M.get_plugin_state(plugin_name)
	return M.get("plugins", plugin_name)
end

-- 5. 工具函数
function M.get_project_key()
	local store = _ensure_store()
	return store:_project_key()
end

function M.get_file_path()
	local store = _ensure_store()
	return store.file_path
end

function M.force_save()
	local store = _ensure_store()
	return store:save()
end

function M.clear_project_data()
	local store = _ensure_store()
	local pkey = store:_project_key()
	local data = store:load()

	data[pkey] = nil
	store.data = data
	store._dirty = true
	if store.auto_save then
		store:save()
	end
end

return M
