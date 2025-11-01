local M = {}

-- 初始化存储实例
function M:new(config)
	local instance = {
		file_path = config.file_path,
		default_data = config.default_data or {},
	}
	setmetatable(instance, { __index = self })
	return instance
end

-- 确保文件目录存在
local function ensure_dir(path)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p", "0755")
	end
end

-- 加载数据
function M:load()
	local file = io.open(self.file_path, "r")
	if not file then
		return vim.deepcopy(self.default_data)
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		return data
	end

	return vim.deepcopy(self.default_data)
end

-- 保存数据（美化 JSON）
function M:save(data)
	ensure_dir(self.file_path)
	local file = io.open(self.file_path, "w")
	if not file then
		return false
	end

	local json_str = vim.json.encode(data, { pretty = true })
	file:write(json_str)
	file:close()
	return true
end

-- 获取特定键
function M:get(key)
	local data = self:load()
	return data[key]
end

-- 设置特定键
function M:set(key, value)
	local data = self:load()
	data[key] = value
	return self:save(data)
end

-- 删除特定键
function M:delete(key)
	local data = self:load()
	data[key] = nil
	return self:save(data)
end

return M
