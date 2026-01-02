-- lua/todo/link/cleaner.lua
local M = {}

local store = require("todo.store")

function M.cleanup_all_links()
	local todo_cleaned = 0
	local code_cleaned = 0

	-- 清理 todo_links 命名空间
	local all_todo = store.get_all_todo_links()
	if all_todo then
		for id, info in pairs(all_todo) do
			-- 检查TODO文件是否存在
			local file_ok, todo_lines = pcall(vim.fn.readfile, info.path)
			if not file_ok then
				store.delete_todo_link(id)
				todo_cleaned = todo_cleaned + 1
			else
				-- 检查ID是否还在文件中
				local found = false
				for _, line in ipairs(todo_lines) do
					if line:match("{#" .. id .. "}") then
						found = true
						break
					end
				end
				if not found then
					store.delete_todo_link(id)
					todo_cleaned = todo_cleaned + 1
				end
			end
		end
	end

	-- 清理 code_links 命名空间
	local all_code = store.get_all_code_links()
	if all_code then
		for id, info in pairs(all_code) do
			-- 检查代码文件是否存在
			local file_ok, code_lines = pcall(vim.fn.readfile, info.path)
			if not file_ok then
				store.delete_code_link(id)
				code_cleaned = code_cleaned + 1
			else
				-- 检查TODO标记是否还在文件中
				local found = false
				for _, line in ipairs(code_lines) do
					if line:match("TODO:ref:" .. id) then
						found = true
						break
					end
				end
				if not found then
					store.delete_code_link(id)
					code_cleaned = code_cleaned + 1
				end
			end
		end
	end

	print(
		string.format("✅ 清理完成，清理了 %d 个TODO链接和 %d 个代码链接", todo_cleaned, code_cleaned)
	)
end

return M
