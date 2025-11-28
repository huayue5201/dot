local JsonHandler = require("json-handler")

local M = {}

M.config = {
	state_dir = vim.fn.stdpath("cache") .. "/project-states", -- 使用缓存目录
	auto_save = false, -- 默认不自动保存，由调用方控制
}

-- 基础状态结构（保持扩展性但实际使用时可简化）
M.default_state = {
	metadata = {
		version = "1.0.0",
		project_id = "",
		project_name = "",
		project_root = "",
		last_updated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	},
	-- 其他字段按需动态添加
}

-- 项目检测（简化版）
function M:_detect_project()
	local cwd = vim.fn.getcwd()

	-- 尝试检测 Git 项目
	local git_dir = vim.fn.finddir(".git", cwd .. ";")
	if git_dir ~= "" then
		local project_root = vim.fn.fnamemodify(git_dir, ":h")
		return {
			root = project_root,
			name = vim.fn.fnamemodify(project_root, ":t"),
			id = vim.fn.hash(project_root),
			type = "git",
		}
	end

	-- 回退到当前目录
	return {
		root = cwd,
		name = vim.fn.fnamemodify(cwd, ":t"),
		id = vim.fn.hash(cwd),
		type = "directory",
	}
end

-- 获取当前项目的状态处理器
function M:_get_project_handler()
	if not self._current_handler then
		local project = self:_detect_project()
		local state_path = self.config.state_dir .. "/" .. project.id .. ".json"

		-- 确保目录存在
		if vim.fn.isdirectory(self.config.state_dir) == 0 then
			vim.fn.mkdir(self.config.state_dir, "p", "0755")
		end

		-- 准备项目元数据
		local default_data = vim.deepcopy(M.default_state)
		default_data.metadata.project_id = project.id
		default_data.metadata.project_name = project.name
		default_data.metadata.project_root = project.root

		self._current_handler = JsonHandler:new({
			file_path = state_path,
			default_data = default_data,
			auto_save = self.config.auto_save,
		})

		self._current_project = project
	end

	return self._current_handler
end

-- 异步保存状态数据
function M:_async_save(handler, callback)
	vim.loop.fs_open(handler.file_path, "w", 438, function(err, fd)
		if err then
			print("Error opening file for saving:", err)
			return
		end
		local data = vim.fn.json_encode(handler.data)
		vim.loop.fs_write(fd, data, 0, function(err)
			if err then
				print("Error writing data:", err)
				return
			end
			vim.loop.fs_close(fd, function()
				if callback then
					callback()
				end
			end)
		end)
	end)
end

-- 核心 API：写入状态数据
function M:write_state(data, options)
	options = options or {}
	local handler = self:_get_project_handler()

	-- 更新元数据时间戳
	local current_state = handler:load()
	current_state.metadata.last_updated = os.date("!%Y-%m-%dT%H:%M:%SZ")
	handler:set("metadata", current_state.metadata)

	-- 写入数据
	if options.merge then
		-- 合并模式：将数据合并到现有状态中
		for key, value in pairs(data) do
			if type(value) == "table" and type(current_state[key]) == "table" then
				-- 深度合并表格
				current_state[key] = vim.tbl_deep_extend("force", current_state[key] or {}, value)
			else
				current_state[key] = value
			end
		end
		handler.data = current_state
	else
		-- 直接设置模式
		for key, value in pairs(data) do
			handler:set(key, value)
		end
	end

	-- 异步保存
	if options.save ~= false then -- 默认保存
		self:_async_save(handler, function()
			print("State saved successfully")
		end)
	else
		handler._dirty = true
		return true
	end
end

-- 读取状态数据
function M:read_state(key)
	local handler = self:_get_project_handler()
	if key then
		return handler:get(key)
	else
		return handler:load()
	end
end

-- 删除状态数据
function M:delete_state(key)
	local handler = self:_get_project_handler()
	handler:delete(key)
	return handler:save()
end

-- 获取当前项目信息
function M:get_project_info()
	if not self._current_project then
		self:_get_project_handler() -- 这会初始化项目信息
	end
	return self._current_project
end

-- 强制保存当前状态
function M:save()
	local handler = self:_get_project_handler()
	self:_async_save(handler, function()
		print("State saved successfully")
	end)
end

-- 重新加载状态（从文件重新读取）
function M:reload()
	if self._current_handler then
		self._current_handler.data = nil -- 清除缓存
	end
	return self:read_state()
end

-- 初始化配置
function M:setup(user_config)
	self.config = vim.tbl_deep_extend("force", self.config, user_config or {})
end

return M
