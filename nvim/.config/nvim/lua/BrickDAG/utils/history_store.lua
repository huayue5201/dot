local M = {}
local history_file = vim.fn.stdpath("data") .. "/brickdag_history.json"

function M.load_recent(limit)
	if vim.fn.filereadable(history_file) == 0 then
		return {}
	end

	local content = vim.fn.readfile(history_file)
	if #content == 0 then
		return {}
	end

	local ok, history = pcall(vim.json.decode, table.concat(content, "\n"))
	if not ok then
		return {}
	end

	-- 按时间倒序排序
	table.sort(history, function(a, b)
		return a.timestamp > b.timestamp
	end)

	return vim.list_slice(history, 1, limit or 10)
end

function M.add(task_name, status)
	local history = M.load_recent(100) -- 加载更多记录
	table.insert(history, 1, {
		name = task_name,
		status = status,
		time = os.date("%Y-%m-%d %H:%M:%S"),
		timestamp = os.time(),
	})

	-- 保存到文件
	vim.fn.writefile({ vim.json.encode(history) }, history_file)
end

return M
