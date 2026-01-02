-- lua/todo/core/parser.lua
local M = {}

-- 缓存机制
local task_cache = {}
local CACHE_TTL = 5000 -- 5 秒缓存

-- 缓存 sha256 函数的可用性
local sha256_available = nil

local function compute_cache_key(bufnr, lines)
	if #lines == 0 then
		return bufnr .. ":empty"
	end

	local text = table.concat(lines, "\n")
	local length = #text

	-- 只检查一次 sha256 是否可用
	if sha256_available == nil then
		sha256_available = pcall(vim.fn.sha256, "test")
	end

	-- 对于小文件，使用简单方法；对于大文件，使用哈希
	if length < 1000 then
		-- 小文件：直接使用文本（性能更好）
		return bufnr .. ":" .. length .. ":" .. text
	else
		-- 大文件：使用哈希（内存更友好）
		if sha256_available then
			local hash = vim.fn.sha256(text)
			return bufnr .. ":" .. hash
		else
			-- 回退：使用文本的前中后部分
			local prefix = text:sub(1, 50)
			local middle = text:sub(math.floor(length / 2) - 25, math.floor(length / 2) + 25)
			local suffix = text:sub(length - 49, length)
			return string.format("%d:%d:%s%s%s", bufnr, length, prefix, middle, suffix)
		end
	end
end

local function get_cached_tasks(bufnr, lines)
	local cache_key = compute_cache_key(bufnr, lines)
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
