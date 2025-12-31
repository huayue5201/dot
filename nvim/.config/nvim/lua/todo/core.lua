-- lua/user/todo/core.lua
local M = {}

-- 在 core.lua 开头添加缓存
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

-- 修改解析函数使用缓存
function M.parse_tasks_with_cache(bufnr, lines)
	return get_cached_tasks(bufnr, lines)
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
	}
end

---------------------------------------------------------------------
-- 任务树解析（一次解析即可）
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
function M.sync_parent_child_state(tasks, bufnr)
	local changed = false

	for _, task in ipairs(tasks) do
		if #task.children > 0 then
			local stats = task.stats
			if not stats then
				stats = require("todo.core").calc_stats(task)
			end

			local should_done = stats.done == stats.total
			local current_done = task.is_done

			if should_done ~= current_done then
				-- 自动更新父任务状态
				local line = vim.api.nvim_buf_get_lines(bufnr, task.line_num - 1, task.line_num, false)[1]
				if line then
					if should_done then
						local new_line = line:gsub("%[ %]", "[x]")
						vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
						task.is_done = true
					else
						local new_line = line:gsub("%[[xX]%]", "[ ]")
						vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
						task.is_done = false
					end
					changed = true
				end
			end
		end
	end

	return changed
end

function M.refresh(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = core.parse_tasks(lines)

	-- 只计算一次统计
	core.calculate_all_stats(tasks)

	-- 同步父子状态，如果需要重新计算，则重新计算
	if core.sync_parent_child_state(tasks, bufnr) then
		-- 如果有父任务状态改变，重新解析并计算
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		tasks = core.parse_tasks(lines)
		core.calculate_all_stats(tasks)
	end

	local roots = core.get_root_tasks(tasks)
	render.render_all(bufnr, roots)

	return tasks
end

---------------------------------------------------------------------
-- 切换任务状态（包含递归切换子任务）
---------------------------------------------------------------------

local function toggle_task_and_children(task, bufnr, new_status)
	-- 切换当前任务
	local line = vim.api.nvim_buf_get_lines(bufnr, task.line_num - 1, task.line_num, false)[1]
	if line then
		if new_status then
			-- 设置特定状态
			local new_line = new_status and line:gsub("%[ %]", "[x]") or line:gsub("%[[xX]%]", "[ ]")
			vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
			task.is_done = new_status
		else
			-- 切换状态
			if line:match("%[ %]") then
				local new_line = line:gsub("%[ %]", "[x]")
				vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
				task.is_done = true
				new_status = true
			else
				local new_line = line:gsub("%[[xX]%]", "[ ]")
				vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
				task.is_done = false
				new_status = false
			end
		end
	end

	-- 递归切换子任务
	for _, child in ipairs(task.children) do
		toggle_task_and_children(child, bufnr, new_status)
	end
end

function M.toggle_line(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = M.parse_tasks(lines)

	-- 找到当前行的任务
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

	-- 切换任务及其子任务
	toggle_task_and_children(current_task, bufnr, nil)

	return true, current_task.is_done
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
