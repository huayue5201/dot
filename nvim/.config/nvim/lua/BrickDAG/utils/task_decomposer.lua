local M = {}

function M.decompose_task(task)
	local bricks = {}

	-- 基础积木解析
	if task.cwd then
		table.insert(bricks, { type = "cwd", value = task.cwd, name = "工作目录" })
	end

	if task.cmd then
		table.insert(bricks, { type = "cmd", value = task.cmd, name = "执行命令" })
	end

	if task.args then
		table.insert(bricks, {
			type = "args",
			value = table.concat(task.args, " "),
			name = "命令参数",
		})
	end

	if task.env then
		table.insert(bricks, {
			type = "env",
			value = vim.inspect(task.env),
			name = "环境变量",
		})
	end

	-- 框架积木
	if task[task.type] then
		table.insert(bricks, {
			type = "frame",
			name = task.type,
			value = vim.inspect(task[task.type]),
			config = task[task.type],
		})
	end

	return bricks
end

return M
