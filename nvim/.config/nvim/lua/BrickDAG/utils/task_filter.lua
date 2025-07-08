local M = {}

--- 检测当前 buffer 文件类型是否匹配
local function matches_filetype(task)
	if not task.filetypes then
		return true
	end

	local ft = vim.bo.filetype
	for _, t in ipairs(task.filetypes) do
		if t == ft then
			return true
		end
	end
	return false
end

--- 检测是否匹配项目根目录
local function matches_root(task)
	if not task.root_patterns then
		return true
	end

	local cwd = vim.fn.getcwd()
	for _, pattern in ipairs(task.root_patterns) do
		local match = vim.fn.glob(cwd .. "/" .. pattern)
		if match ~= "" then
			return true
		end
	end
	return false
end

--- 对任务列表进行过滤
function M.filter(tasks)
	local result = {}
	for _, task in ipairs(tasks) do
		if matches_filetype(task) and matches_root(task) then
			table.insert(result, task)
		end
	end
	return result
end

return M
