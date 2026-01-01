-- lua/todo/core.lua
local M = {}

---------------------------------------------------------------------
-- 缓存系统（毫秒级 TTL）
---------------------------------------------------------------------

-- 使用 uv.now()（毫秒）而不是 os.time（秒）
local uv = vim.uv or vim.loop

local task_cache = {}
local CACHE_TTL = 5000 -- 5 秒（毫秒）

local function now_ms()
	return uv and uv.now() or (os.time() * 1000)
end

local function make_cache_key(bufnr, lines)
	-- 简单但足够：bufnr + 行数 + 第一行 + 最后一行
	local first = lines[1] or ""
	local last = lines[#lines] or ""
	return table.concat({
		tostring(bufnr),
		"#",
		tostring(#lines),
		"#",
		first,
		"#",
		last,
	})
end

local function get_cached_tasks(bufnr, lines)
	local key = make_cache_key(bufnr, lines)
	local entry = task_cache[key]
	local now = now_ms()

	if entry and (entry.timestamp + CACHE_TTL > now) then
		return entry.tasks
	end

	local tasks = M.parse_tasks(lines)

	task_cache[key] = {
		tasks = tasks,
		timestamp = now,
	}

	-- 简单清理过期缓存
	for k, v in pairs(task_cache) do
		if v.timestamp + CACHE_TTL <= now then
			task_cache[k] = nil
		end
	end

	return tasks
end

-- 对外暴露：带缓存的解析
function M.parse_tasks_with_cache(bufnr, lines)
	return get_cached_tasks(bufnr, lines)
end

-- 当 buffer 内容被修改时，可以调用这个清理（由外部决定是否用）
function M.invalidate_cache()
	task_cache = {}
end

---------------------------------------------------------------------
-- 工具函数
---------------------------------------------------------------------

local function get_indent(line)
	local indent = line:match("^(%s*)")
	return indent and #indent or 0
end

local function is_task_line(line)
	return line:match("^%s*[-*]%s+%[[ xX]%]")
end

local function parse_task_line(line)
	local indent = get_indent(line)
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
		stats = nil,
	}
end

---------------------------------------------------------------------
-- 任务树解析
---------------------------------------------------------------------

function M.parse_tasks(lines)
	local tasks = {}
	local stack = {}

	for i, line in ipairs(lines) do
		if is_task_line(line) then
			local task = parse_task_line(line)
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
-- 统计（递归）
---------------------------------------------------------------------

local function calc_stats(task)
	if task.stats then
		return task.stats
	end

	local stats = { total = 0, done = 0 }

	if #task.children == 0 then
		stats.total = 1
		stats.done = task.is_done and 1 or 0
	else
		for _, child in ipairs(task.children) do
			local s = calc_stats(child)
			stats.total = stats.total + s.total
			stats.done = stats.done + s.done
		end
	end

	task.stats = stats
	return stats
end

-- 如果外部真的需要，可以暴露
M.calc_stats = calc_stats

function M.calculate_all_stats(tasks)
	for _, t in ipairs(tasks) do
		if not t.parent then
			calc_stats(t)
		end
	end
end

---------------------------------------------------------------------
-- 父子任务联动（不重新解析）
---------------------------------------------------------------------

local function set_task_line_status(bufnr, task, new_done)
	local line = vim.api.nvim_buf_get_lines(bufnr, task.line_num - 1, task.line_num, false)[1]
	if not line then
		return false
	end

	local new_line
	if new_done then
		new_line = line:gsub("%[ %]", "[x]")
		new_line = new_line:gsub("%[[X]%]", "[x]")
	else
		new_line = line:gsub("%[[xX]%]", "[ ]")
	end

	if new_line ~= line then
		vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
		task.is_done = new_done
		task.status = new_done and "[x]" or "[ ]"
		task.stats = nil -- 失效统计
		return true
	end

	return false
end

function M.sync_parent_child_state(tasks, bufnr)
	local changed = false

	for _, task in ipairs(tasks) do
		if #task.children > 0 then
			local stats = task.stats or calc_stats(task)
			local should_done = (stats.done == stats.total)
			local current_done = task.is_done

			if should_done ~= current_done then
				if set_task_line_status(bufnr, task, should_done) then
					changed = true
				end
			end
		end
	end

	if changed then
		-- 父任务状态改变后，缓存不再可靠
		M.invalidate_cache()
	end

	return changed
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
-- 刷新：解析 + 统计 + 父子联动 + 渲染
---------------------------------------------------------------------

function M.refresh(bufnr)
	local render = require("todo.render")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = M.parse_tasks(lines)

	-- 只计算一次统计
	M.calculate_all_stats(tasks)

	-- 同步父子状态，如果需要重新计算，则重新解析并计算
	if M.sync_parent_child_state(tasks, bufnr) then
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		tasks = M.parse_tasks(lines)
		M.calculate_all_stats(tasks)
	end

	local roots = M.get_root_tasks(tasks)
	render.render_all(bufnr, roots)

	return tasks
end

---------------------------------------------------------------------
-- 切换任务状态（包含递归切换子任务）
---------------------------------------------------------------------

local function toggle_task_and_children(task, bufnr, new_status, visited)
	visited = visited or {}
	if visited[task] then
		return
	end
	visited[task] = true

	local line = vim.api.nvim_buf_get_lines(bufnr, task.line_num - 1, task.line_num, false)[1]
	if line then
		if new_status ~= nil then
			-- 设置特定状态
			local target_done = new_status and true or false
			set_task_line_status(bufnr, task, target_done)
			new_status = target_done
		else
			-- 切换状态
			local is_done = line:match("%[ %]") == nil
			local target_done = not is_done
			set_task_line_status(bufnr, task, target_done)
			new_status = target_done
		end
	end

	for _, child in ipairs(task.children) do
		toggle_task_and_children(child, bufnr, new_status, visited)
	end
end

function M.toggle_line(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = M.parse_tasks(lines)

	local current_task = nil
	for _, task in ipairs(tasks) do
		if task.line_num == lnum then
			current_task = task
			break
		end
	end

	if not current_task then
		return false, "不是任务行"
	end

	toggle_task_and_children(current_task, bufnr, nil)

	-- 切换后缓存失效
	M.invalidate_cache()

	return true, current_task.is_done
end

---------------------------------------------------------------------
-- 统计摘要（用于 footer）
---------------------------------------------------------------------

function M.summarize(lines)
	local tasks = M.parse_tasks(lines)
	local count = {
		todo = 0,
		done = 0,
		total_items = 0,
		completed_items = 0,
	}

	for _, t in ipairs(tasks) do
		if not t.parent then
			if t.is_done then
				count.done = count.done + 1
			else
				count.todo = count.todo + 1
			end
		end

		count.total_items = count.total_items + 1
		if t.is_done then
			count.completed_items = count.completed_items + 1
		end
	end

	count.total_tasks = count.todo + count.done
	return count
end

return M
