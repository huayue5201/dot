-- lua/utils/json_store.lua
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
		-- 文件不存在时返回默认数据
		return vim.deepcopy(self.default_data)
	end

	local content = file:read("*a")
	file:close()

	local ok, data = pcall(vim.fn.json_decode, content)
	if ok and type(data) == "table" then
		return data
	end

	-- 解析失败时返回默认数据
	return vim.deepcopy(self.default_data)
end

-- 保存数据
function M:save(data)
	ensure_dir(self.file_path)

	local file = io.open(self.file_path, "w")
	if file then
		local json_str = vim.fn.json_encode(data)
		file:write(json_str)
		file:close()
		return true
	end
	return false
end

-- 获取特定键的值
function M:get(key)
	local data = self:load()
	return data[key]
end

-- 设置特定键的值
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
