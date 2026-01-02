-- lua/todo/ui/file_manager.lua
local M = {}

---------------------------------------------------------------------
-- 文件缓存
---------------------------------------------------------------------
local _file_cache = {}

local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_project_dir(project)
	return vim.fn.expand("~/.todo-files/" .. project)
end

function M.get_todo_files(project, force_refresh)
	if not force_refresh and _file_cache[project] then
		return _file_cache[project]
	end

	local dir = get_project_dir(project)
	if vim.fn.isdirectory(dir) == 0 then
		_file_cache[project] = {}
		return {}
	end

	local files = vim.fn.globpath(dir, "*.todo.md", false, true)
	_file_cache[project] = files
	return files
end

---------------------------------------------------------------------
-- 选择 TODO 文件
---------------------------------------------------------------------
function M.select_todo_file(scope, callback)
	local choices = {}
	local projects = {}

	if scope == "current" then
		local project = get_project()
		projects = { project }
	elseif scope == "all" then
		local root = vim.fn.expand("~/.todo-files")
		local handle = vim.loop.fs_scandir(root)
		if handle then
			while true do
				local name = vim.loop.fs_scandir_next(handle)
				if not name then
					break
				end
				table.insert(projects, name)
			end
		end
	end

	for _, project in ipairs(projects) do
		for _, f in ipairs(M.get_todo_files(project)) do
			table.insert(choices, { project = project, path = f })
		end
	end

	if #choices == 0 then
		vim.notify("未找到 TODO 文件", vim.log.levels.WARN)
		return
	end

	vim.ui.select(choices, {
		prompt = "🗂️ 选择 TODO 文件：",
		format_item = function(item)
			return string.format("%-20s • %s", item.project, vim.fn.fnamemodify(item.path, ":t"))
		end,
	}, callback)
end

---------------------------------------------------------------------
-- 创建 TODO 文件
---------------------------------------------------------------------
function M.create_todo_file(default_name)
	local project = get_project()
	local dir = get_project_dir(project)
	vim.fn.mkdir(dir, "p")

	-- 如果有默认文件名，使用它，否则提示用户输入
	local filename = default_name or vim.fn.input("📝 请输入 TODO 文件名: ")
	if filename == "" then
		return nil
	end

	if not filename:match("%.todo%.md$") then
		filename = filename .. ".todo.md"
	end

	local path = dir .. "/" .. filename
	if vim.fn.filereadable(path) == 1 then
		vim.notify("文件已存在: " .. filename, vim.log.levels.WARN)
		return path -- 返回现有文件的路径
	end

	local fd = io.open(path, "w")
	if fd then
		fd:write("# TODO - " .. filename:gsub("%.todo%.md$", "") .. "\n\n")
		fd:close()
		vim.notify("创建成功: " .. path, vim.log.levels.INFO)

		-- 清除缓存，确保新文件能立即显示
		_file_cache = {}

		return path
	else
		vim.notify("无法创建文件: " .. path, vim.log.levels.ERROR)
		return nil
	end
end

---------------------------------------------------------------------
-- 删除 TODO 文件
---------------------------------------------------------------------
function M.delete_todo_file(path)
	if not vim.fn.filereadable(path) then
		vim.notify("文件不存在: " .. path, vim.log.levels.ERROR)
		return false
	end

	local confirm = vim.fn.input("🗑️ 确定删除 " .. vim.fn.fnamemodify(path, ":t") .. " 吗? (y/n): "):lower()
	if confirm == "y" then
		local success = os.remove(path)
		if success then
			vim.notify("删除成功", vim.log.levels.INFO)
			-- 清除缓存
			_file_cache = {}
			return true
		else
			vim.notify("删除失败", vim.log.levels.ERROR)
			return false
		end
	end
	return false
end

---------------------------------------------------------------------
-- 清理缓存
---------------------------------------------------------------------
function M.clear_cache()
	_file_cache = {}
	vim.notify("已清除文件缓存", vim.log.levels.INFO)
end

return M
