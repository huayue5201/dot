-- lua/todo/link/searcher.lua
local M = {}

local store = require("todo.store")

function M.search_links_by_file(filepath)
	local todo_results = store.find_todo_links_by_file(filepath)
	local code_results = store.find_code_links_by_file(filepath)

	return {
		todo_links = todo_results,
		code_links = code_results,
	}
end

function M.search_links_by_pattern(pattern)
	local todo_all = store.get_all_todo_links()
	local code_all = store.get_all_code_links()
	local results = {}

	-- 搜索TODO链接
	for id, link in pairs(todo_all) do
		-- 读取文件内容
		local ok, lines = pcall(vim.fn.readfile, link.path)
		if ok then
			local line_content = lines[link.line] or ""
			if line_content:match(pattern) then
				results[id] = {
					type = "todo",
					link = link,
					content = line_content,
				}
			end
		end
	end

	-- 搜索代码链接
	for id, link in pairs(code_all) do
		local ok, lines = pcall(vim.fn.readfile, link.path)
		if ok then
			local line_content = lines[link.line] or ""
			if line_content:match(pattern) then
				results[id] = {
					type = "code",
					link = link,
					content = line_content,
				}
			end
		end
	end

	return results
end

return M
