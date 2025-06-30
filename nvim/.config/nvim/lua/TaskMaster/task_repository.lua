-- 任务仓库 (task_repository.lua)

local Path = require("plenary.path")
local scandir = require("plenary.scandir")

local TaskRepository = {}
TaskRepository.__index = TaskRepository

function TaskRepository:new()
	return setmetatable({
		tasks = {},
		manager = nil,
		task_dirs = {
			vim.fn.stdpath("config") .. "/lua/tasks",
			vim.fn.getcwd() .. "/.nvim/tasks",
		},
	}, self)
end

function TaskRepository:load_tasks()
	self.tasks = {}

	for _, dir in ipairs(self.task_dirs) do
		local dir_path = Path:new(dir)
		if dir_path:exists() and dir_path:is_dir() then
			local files = scandir.scan_dir(dir, {
				search_pattern = "%.lua$",
				depth = 1,
			})

			for _, file in ipairs(files) do
				self:load_task_file(file)
			end
		end
	end
end

function TaskRepository:load_task_file(file_path)
	local ok, chunk = pcall(dofile, file_path)
	if not ok then
		vim.notify("加载任务文件失败: " .. file_path, vim.log.levels.ERROR)
		return
	end

	if type(chunk) ~= "table" or not chunk.id then
		vim.notify("无效任务文件: " .. file_path, vim.log.levels.WARN)
		return
	end

	chunk.label = chunk.label or chunk.id
	self.tasks[chunk.id] = chunk
end

function TaskRepository:get_task_by_id(id)
	return self.tasks[id]
end

function TaskRepository:get_all_tasks()
	return self.tasks
end

function TaskRepository:reload_task(id)
	self:load_tasks()
end

function TaskRepository:async_load_tasks(callback)
	vim.schedule(function()
		self:load_tasks()
		if callback then
			callback()
		end
	end)
end

return TaskRepository
