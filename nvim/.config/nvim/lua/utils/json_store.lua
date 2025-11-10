local M = {}

-- 确保目录存在
local function ensure_dir(path)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end
end

function M:new(config)
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

-- 内部加载文件
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
		vim.notify("⚠️ JSON 解析失败, 使用默认数据: " .. self.file_path, vim.log.levels.WARN)
		return vim.deepcopy(self.default_data)
	end
end

function M:load()
	if not self.data then
		self.data = self:_load_from_file()
	end
	return self.data
end

function M:save()
	if not self.data then
		return false
	end
	ensure_dir(self.file_path)

	local ok, json_str = pcall(vim.json.encode, self.data, { indent = true })
	if not ok or not json_str then
		json_str = vim.fn.json_encode(self.data):gsub(',"', ',\n  "'):gsub("{", "{\n  "):gsub("}", "\n}")
	end

	local f = io.open(self.file_path, "w")
	if not f then
		vim.notify("❌ 无法写入 JSON 文件: " .. self.file_path, vim.log.levels.ERROR)
		return false
	end
	f:write(json_str)
	f:close()

	self._dirty = false
	return true
end

function M:flush()
	if self._dirty then
		return self:save()
	end
end

function M:get(key)
	return self:load()[key]
end

function M:set(key, value)
	local data = self:load()
	data[key] = value
	self._dirty = true
	if self.auto_save then
		self:save()
	end
end

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

function M:clear()
	self.data = vim.deepcopy(self.default_data)
	self._dirty = true
	if self.auto_save then
		self:save()
	end
end

return M
