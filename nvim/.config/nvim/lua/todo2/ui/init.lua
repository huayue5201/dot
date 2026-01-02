-- lua/todo/ui/init.lua
local M = {}

-- 延迟加载子模块
local modules = {
	constants = nil,
	conceal = nil,
	operations = nil,
	file_manager = nil,
	statistics = nil,
	keymaps = nil,
	window = nil,
}

-- 动态获取模块
local function get_module(name)
	if not modules[name] then
		modules[name] = require("todo2.ui." .. name)
	end
	return modules[name]
end

-- 导入 render 模块（外部依赖）
local render = require("todo2.render")

-- 内部状态
local window_switcher = nil

---------------------------------------------------------------------
-- 刷新渲染
---------------------------------------------------------------------
function M.refresh(bufnr)
	local core = require("todo2.core")
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local tasks = core.parse_tasks(lines)
	core.calculate_all_stats(tasks)
	core.sync_parent_child_state(tasks, bufnr)
	core.calculate_all_stats(tasks)

	local roots = core.get_root_tasks(tasks)
	render.render_all(bufnr, roots)

	return tasks
end

---------------------------------------------------------------------
-- 初始化窗口切换器
---------------------------------------------------------------------
local function init_window_switcher()
	if not window_switcher then
		local keymaps = get_module("keymaps")
		window_switcher = keymaps.create_window_switcher(M)

		-- 将切换函数添加到 M 模块
		M.switch_to_float = window_switcher.switch_to_float
		M.switch_to_split = window_switcher.switch_to_split
	end
	return window_switcher
end

---------------------------------------------------------------------
-- 打开 TODO 文件（支持多种模式）
---------------------------------------------------------------------
function M.open_todo_file(path, mode, line_number, opts)
	opts = opts or {}
	local enter_insert = opts.enter_insert ~= false
	local split_direction = opts.split_direction or "horizontal"

	-- 确保路径是绝对路径
	path = vim.fn.fnamemodify(path, ":p")

	-- 检查文件是否存在
	if vim.fn.filereadable(path) == 0 then
		vim.notify("TODO文件不存在: " .. path, vim.log.levels.ERROR)
		return
	end

	-- 默认行号为1（文件开头）
	line_number = line_number or 1

	-- 调用对应的窗口函数
	local window = get_module("window")
	if mode == "float" then
		return window.show_floating(path, line_number, enter_insert, M)
	elseif mode == "split" then
		return window.show_split(path, line_number, enter_insert, split_direction, M)
	elseif mode == "edit" then
		return window.show_edit(path, line_number, enter_insert, M)
	else
		-- 默认编辑模式
		return window.show_edit(path, line_number, enter_insert, M)
	end
end

---------------------------------------------------------------------
-- 公开 API
---------------------------------------------------------------------

-- 文件选择
function M.select_todo_file(scope, callback)
	return get_module("file_manager").select_todo_file(scope, callback)
end

-- 创建 TODO 文件
function M.create_todo_file()
	return get_module("file_manager").create_todo_file()
end

-- 删除 TODO 文件
function M.delete_todo_file(path)
	return get_module("file_manager").delete_todo_file(path)
end

-- 批量切换任务
function M.toggle_selected_tasks()
	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.fn.bufwinid(bufnr)

	if win == -1 then
		vim.notify("未在窗口中找到缓冲区", vim.log.levels.ERROR)
		return 0
	end

	local operations = get_module("operations")
	local changed = operations.toggle_selected_tasks(bufnr, win)
	M.refresh(bufnr)
	return changed
end

-- 插入任务
function M.insert_task(text, indent_extra, bufnr)
	local operations = get_module("operations")
	return operations.insert_task(text, indent_extra, bufnr, M)
end

-- 清理缓存
function M.clear_cache()
	return get_module("file_manager").clear_cache()
end

---------------------------------------------------------------------
-- 工具函数
---------------------------------------------------------------------

-- 获取常量
function M.get_constants()
	return get_module("constants")
end

-- 应用 conceal
function M.apply_conceal(bufnr)
	return get_module("conceal").apply_conceal(bufnr)
end

-- 获取窗口模块
function M.get_window_module()
	return get_module("window")
end

-- 获取键位模块
function M.get_keymaps_module()
	return get_module("keymaps")
end

-- 重新加载所有子模块（用于调试）
function M.reload_modules()
	for name, _ in pairs(modules) do
		package.loaded["todo.ui." .. name] = nil
		modules[name] = nil
	end
	package.loaded["todo.ui"] = nil
	window_switcher = nil

	-- 重新加载当前模块
	return require("todo2.ui")
end

return M
