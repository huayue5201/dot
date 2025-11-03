local M = {}

-- 确保文件目录存在
local function ensure_dir(path)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end
end

-- 创建实例
function M:new(config)
	local instance = {
		file_path = config.file_path,
		default_data = config.default_data or {},
		data = nil, -- 缓存数据（延迟加载）
		_dirty = false, -- 是否需要保存
		auto_save = config.auto_save or false, -- 可选：自动写入文件
	}
	setmetatable(instance, { __index = self })
	return instance
end

-- 内部加载数据
function M:_load_from_file()
	local file = io.open(self.file_path, "r")
	if not file then
		return vim.deepcopy(self.default_data)
	end
	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	else
		vim.notify("⚠️ JSON 解析失败，已重置默认数据: " .. self.file_path, vim.log.levels.WARN)
		return vim.deepcopy(self.default_data)
	end
end

-- 加载（带缓存）
function M:load()
	if not self.data then
		self.data = self:_load_from_file()
	end
	return self.data
end

-- 保存到文件
function M:save()
	if not self.data then
		return false
	end
	ensure_dir(self.file_path)

	local ok, json_str
	local ok_indent = pcall(function()
		json_str = vim.json.encode(self.data, { indent = true })
	end)

	if not ok_indent or not json_str then
		local compact = vim.fn.json_encode(self.data)
		json_str = compact:gsub(',"', ',\n  "'):gsub("{", "{\n  "):gsub("}", "\n}")
	end

	local file = io.open(self.file_path, "w")
	if not file then
		vim.notify("❌ 无法写入 JSON 文件: " .. self.file_path, vim.log.levels.ERROR)
		return false
	end
	file:write(json_str)
	file:close()

	self._dirty = false
	return true
end

-- 手动刷新到文件
function M:flush()
	if self._dirty then
		return self:save()
	end
end

-- 获取键
function M:get(key)
	local data = self:load()
	return data[key]
end

-- 设置键
function M:set(key, value)
	local data = self:load()
	data[key] = value
	self._dirty = true
	if self.auto_save then
		self:save()
	end
end

-- 删除键
function M:delete(key)
	local data = self:load()
	if data[key] ~= nil then
		data[key] = nil
		self._dirty = true
		if self.auto_save then
			self:save()
		end
	end
end

-- 清空数据
function M:clear()
	self.data = vim.deepcopy(self.default_data)
	self._dirty = true
	if self.auto_save then
		self:save()
	end
end

return M
