-- lua/todo/core/init.lua
local M = {}

-- 延迟加载子模块
local modules = {
	parser = nil,
	stats = nil,
	sync = nil,
	toggle = nil,
}

-- 动态获取模块
local function get_module(name)
	if not modules[name] then
		modules[name] = require("todo.core." .. name)
	end
	return modules[name]
end

---------------------------------------------------------------------
-- 重新导出所有函数，保持API兼容性
---------------------------------------------------------------------

-- 解析模块的函数
function M.parse_tasks_with_cache(bufnr, lines)
	return get_module("parser").parse_tasks_with_cache(bufnr, lines)
end

function M.parse_tasks(lines)
	return get_module("parser").parse_tasks(lines)
end

function M.get_root_tasks(tasks)
	return get_module("parser").get_root_tasks(tasks)
end

-- 统计模块的函数
function M.calculate_all_stats(tasks)
	return get_module("stats").calculate_all_stats(tasks)
end

function M.summarize(lines)
	return get_module("stats").summarize(lines)
end

-- 同步模块的函数
function M.sync_parent_child_state(tasks, bufnr)
	return get_module("sync").sync_parent_child_state(tasks, bufnr)
end

function M.refresh(bufnr)
	-- 需要传递当前的core模块给sync.refresh，以便访问render
	local core_module = require("todo")
	return get_module("sync").refresh(bufnr, core_module)
end

-- 切换模块的函数
function M.toggle_line(bufnr, lnum)
	return get_module("toggle").toggle_line(bufnr, lnum)
end

---------------------------------------------------------------------
-- 工具函数（原core.lua中的工具函数）
---------------------------------------------------------------------

-- 这些函数实际上在parser模块中，这里重新导出
function M.get_indent(line)
	return get_module("parser").get_indent(line)
end

function M.is_task_line(line)
	return get_module("parser").is_task_line(line)
end

function M.parse_task_line(line)
	return get_module("parser").parse_task_line(line)
end

-- 缓存清理
function M.clear_cache()
	if modules.parser then
		modules.parser.clear_cache()
	end
	modules = {
		parser = nil,
		stats = nil,
		sync = nil,
		toggle = nil,
	}
end

return M
