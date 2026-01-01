-- lua/todo/store.lua
-- 使用新版 json_store 模块
local json_store = require("json_store")

local M = {}

-- 命名空间：todo_links / code_links
local TODO_NS = "todo_links"
local CODE_NS = "code_links"

-- 在新版中初始化全局命名空间
-- 确保在 Neovim 配置中调用 json_store.setup() 时包含这些命名空间

---------------------------------------------------------------------
-- 保存链接（使用全局存储）
---------------------------------------------------------------------
function M.save_todo_link(id, path, line)
	-- 确保存储绝对路径
	local abs_path = vim.fn.fnamemodify(path, ":p")
	json_store.set(TODO_NS, id, {
		path = abs_path,
		line = line,
		created_at = os.time(),
	}, nil, true) -- 最后一个参数 true 表示使用全局存储
end

function M.save_code_link(id, path, line)
	-- 确保存储绝对路径
	local abs_path = vim.fn.fnamemodify(path, ":p")
	json_store.set(CODE_NS, id, {
		path = abs_path,
		line = line,
		created_at = os.time(),
	}, nil, true) -- 使用全局存储
end

---------------------------------------------------------------------
-- 获取单个链接（从全局获取）
---------------------------------------------------------------------
function M.get_todo_link(id)
	return json_store.get(TODO_NS, id, nil, true) -- 从全局获取
end

function M.get_code_link(id)
	return json_store.get(CODE_NS, id, nil, true) -- 从全局获取
end

---------------------------------------------------------------------
-- 删除链接
---------------------------------------------------------------------
function M.delete_todo_link(id)
	json_store.delete(TODO_NS, id, nil, true)
end

function M.delete_code_link(id)
	json_store.delete(CODE_NS, id, nil, true)
end

---------------------------------------------------------------------
-- 获取全部链接
---------------------------------------------------------------------
function M.get_all_todo_links()
	return json_store.get_all(TODO_NS, true) or {} -- 从全局获取
end

function M.get_all_code_links()
	return json_store.get_all(CODE_NS, true) or {} -- 从全局获取
end

---------------------------------------------------------------------
-- 高级查询：按文件路径查找链接
---------------------------------------------------------------------
function M.find_todo_links_by_file(filepath)
	local all_links = M.get_all_todo_links()
	local results = {}
	local target_path = vim.fn.fnamemodify(filepath, ":p") -- 统一为绝对路径

	for id, link in pairs(all_links) do
		local link_path = vim.fn.fnamemodify(link.path, ":p")
		if link_path == target_path then
			results[id] = link
		end
	end

	return results
end

function M.find_code_links_by_file(filepath)
	local all_links = M.get_all_code_links()
	local results = {}
	local target_path = vim.fn.fnamemodify(filepath, ":p") -- 统一为绝对路径

	for id, link in pairs(all_links) do
		local link_path = vim.fn.fnamemodify(link.path, ":p")
		if link_path == target_path then
			results[id] = link
		end
	end

	return results
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

return M
