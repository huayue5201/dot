-- lua/todo/store.lua
local M = {}

-- 懒加载 json_store 模块
local json_store
local function get_json_store()
	if not json_store then
		json_store = require("json_store")
	end
	return json_store
end

-- 命名空间：todo_links / code_links
local TODO_NS = "todo_links"
local CODE_NS = "code_links"

---------------------------------------------------------------------
-- 保存链接（使用全局存储）
---------------------------------------------------------------------
function M.save_todo_link(id, path, line)
	local abs_path = vim.fn.fnamemodify(path, ":p")
	-- 使用全局存储（use_global = true）
	get_json_store().set(TODO_NS, id, {
		path = abs_path,
		line = line,
		created_at = os.time(),
	}, nil, true)
end

function M.save_code_link(id, path, line)
	local abs_path = vim.fn.fnamemodify(path, ":p")
	-- 使用全局存储（use_global = true）
	get_json_store().set(CODE_NS, id, {
		path = abs_path,
		line = line,
		created_at = os.time(),
	}, nil, true)
end

---------------------------------------------------------------------
-- 获取单个链接（从全局存储）
---------------------------------------------------------------------
function M.get_todo_link(id)
	return get_json_store().get(TODO_NS, id, nil, true)
end

function M.get_code_link(id)
	return get_json_store().get(CODE_NS, id, nil, true)
end

---------------------------------------------------------------------
-- 删除链接（从全局存储）
---------------------------------------------------------------------
function M.delete_todo_link(id)
	get_json_store().delete(TODO_NS, id, nil, true)
end

function M.delete_code_link(id)
	get_json_store().delete(CODE_NS, id, nil, true)
end

---------------------------------------------------------------------
-- 获取全部链接（从全局存储）
---------------------------------------------------------------------
function M.get_all_todo_links()
	return get_json_store().get_all(TODO_NS, true) or {}
end

function M.get_all_code_links()
	return get_json_store().get_all(CODE_NS, true) or {}
end

---------------------------------------------------------------------
-- 高级查询：按文件路径查找链接
---------------------------------------------------------------------
function M.find_todo_links_by_file(filepath)
	local all_links = M.get_all_todo_links()
	local results = {}

	for id, link in pairs(all_links) do
		if link.path == filepath then
			results[id] = link
		end
	end

	return results
end

function M.find_code_links_by_file(filepath)
	local all_links = M.get_all_code_links()
	local results = {}

	for id, link in pairs(all_links) do
		if link.path == filepath then
			results[id] = link
		end
	end

	return results
end

---------------------------------------------------------------------
-- 跨项目查找函数（新添加）
---------------------------------------------------------------------
function M.find_in_all_projects(namespace, key)
	-- 对于 todo_links 和 code_links，我们已经使用全局存储
	-- 所以直接调用 get 即可
	return get_json_store().get(namespace, key, nil, true)
end

function M.get_all_in_namespace(namespace)
	-- 获取全局命名空间的所有数据
	return get_json_store().get_all(namespace, true) or {}
end

---------------------------------------------------------------------
-- 批量操作
---------------------------------------------------------------------
function M.batch_update_todo_links(updates)
	for id, link in pairs(updates) do
		M.save_todo_link(id, link.path, link.line)
	end
end

function M.batch_update_code_links(updates)
	for id, link in pairs(updates) do
		M.save_code_link(id, link.path, link.line)
	end
end

---------------------------------------------------------------------
-- 工具函数：重新加载 json_store 模块
---------------------------------------------------------------------
function M.reload_json_store()
	json_store = nil
	package.loaded["json_store"] = nil
	print("🔄 store: json_store 模块已重新加载")
end

---------------------------------------------------------------------
-- 工具函数：获取存储统计信息
---------------------------------------------------------------------
function M.get_stats()
	local todo_links = M.get_all_todo_links()
	local code_links = M.get_all_code_links()

	return {
		todo_count = #todo_links,
		code_count = #code_links,
		total_count = #todo_links + #code_links,
	}
end

return M
