-- lua/todo/core/parser.lua
local M = {}

-- 缓存机制
local task_cache = {}
local CACHE_TTL = 5000 -- 5 秒缓存

local function get_cached_tasks(bufnr, lines)
	local cache_key = bufnr .. ":" .. table.concat(lines, "")
	local cached = task_cache[cache_key]

	if cached and cached.timestamp + CACHE_TTL > os.time() then
		return cached.tasks
	end

	local tasks = M.parse_tasks(lines)
	task_cache[cache_key] = {
		tasks = tasks,
		timestamp = os.time(),
	}

	-- 清理旧缓存
	for key, data in pairs(task_cache) do
		if data.timestamp + CACHE_TTL < os.time() then
			task_cache[key] = nil
		end
	end

	return tasks
end

---------------------------------------------------------------------
-- 工具函数
---------------------------------------------------------------------

function M.get_indent(line)
	local indent = line:match("^(%s*)")
	return indent and #indent or 0
end

function M.is_task_line(line)
	return line:match("^%s*[-*]%s+%[[ xX]%]")
end

function M.parse_task_line(line)
	local indent = M.get_indent(line)
	local status, content = line:match("^%s*[-*]%s+(%[[ xX]%])%s*(.*)$")
	if not status then
		return nil
	end

	return {
		indent = indent,
		status = status,
		content = content,
		is_done = status == "[x]" or status == "[X]",
		is_todo = status == "[ ]",
		children = {},
		parent = nil,
	}
end

---------------------------------------------------------------------
-- 任务树解析
---------------------------------------------------------------------

function M.parse_tasks(lines)
	local tasks = {}
	local stack = {}

	for i, line in ipairs(lines) do
		if M.is_task_line(line) then
			local task = M.parse_task_line(line)
			if task then
				task.line_num = i

				-- 找父任务
				while #stack > 0 and stack[#stack].indent >= task.indent do
					table.remove(stack)
				end

				if #stack > 0 then
					task.parent = stack[#stack]
					table.insert(stack[#stack].children, task)
				end

				table.insert(tasks, task)
				table.insert(stack, task)
			end
		end
	end

	return tasks
end

---------------------------------------------------------------------
-- 使用缓存的解析函数
---------------------------------------------------------------------

function M.parse_tasks_with_cache(bufnr, lines)
	return get_cached_tasks(bufnr, lines)
end

---------------------------------------------------------------------
-- 收集所有根任务
---------------------------------------------------------------------

function M.get_root_tasks(tasks)
	local roots = {}
	for _, t in ipairs(tasks) do
		if not t.parent then
			table.insert(roots, t)
		end
	end
	return roots
end

---------------------------------------------------------------------
-- 清理缓存
---------------------------------------------------------------------

function M.clear_cache()
	task_cache = {}
end

return M
