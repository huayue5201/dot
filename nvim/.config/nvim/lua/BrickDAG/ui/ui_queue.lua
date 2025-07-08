-- lua/BrickDAG/ui/ui_queue.lua

local task_loader = require("BrickDAG.core.task_loader")
local queue = require("BrickDAG.core.task_queue")
local runner = require("BrickDAG.core.task_runner")
local task_filter = require("BrickDAG.utils.task_filter")

local M = {}

--- 任务详情格式化成多行文本
---@param task table
---@return string[]
local function format_task_details(task)
	local lines = {}

	table.insert(lines, "🔹 Name: " .. (task.name or "N/A"))
	table.insert(lines, "🔹 Type: " .. (task.type or "N/A"))

	if task.cmd then
		table.insert(lines, "🔹 Command: " .. task.cmd)
	end

	if task.args and #task.args > 0 then
		table.insert(lines, "🔹 Args: " .. table.concat(task.args, " "))
	end

	if task.deps and #task.deps > 0 then
		table.insert(lines, "🔹 Dependencies:")
		for _, dep in ipairs(task.deps) do
			table.insert(lines, "   - " .. dep)
		end
	end

	if task.subtasks and #task.subtasks > 0 then
		table.insert(lines, "🔹 Subtasks:")
		for _, sub in ipairs(task.subtasks) do
			table.insert(lines, string.format("   - %s (%s)", sub.name, sub.type or "unknown"))
		end
	end

	if task.filetype then
		table.insert(lines, "🔹 Filetype Filter: " .. task.filetype)
	end

	return lines
end

--- 显示任务详情（浮窗 + 自动关闭）
local function show_task_preview(task)
	vim.defer_fn(function()
		local lines = format_task_details(task)
		local buf = vim.api.nvim_create_buf(false, true)

		local width = 0
		for _, line in ipairs(lines) do
			width = math.max(width, #line)
		end
		local height = #lines

		width = math.min(width + 4, math.floor(vim.o.columns * 0.8))
		height = math.min(height + 2, math.floor(vim.o.lines * 0.5))

		local win = vim.api.nvim_open_win(buf, false, {
			relative = "cursor",
			row = 1,
			col = 0,
			width = width,
			height = height,
			style = "minimal",
			border = "rounded",
		})
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		local autocmd_id
		autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
			callback = function()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
				if autocmd_id then
					pcall(vim.api.nvim_del_autocmd, autocmd_id)
				end
			end,
			once = true,
		})
	end, 150) -- 延迟 100ms 弹窗
end

--- 添加任务到队列
---@param task table
function M.enqueue_task(task)
	queue.enqueue(task)
	vim.notify("已添加到队列: " .. task.name)
end

--- 从任务列表中选择一个任务添加到队列
function M.pick_task_and_enqueue()
	local all_tasks = task_loader.load_tasks()
	if #all_tasks == 0 then
		vim.notify("未找到任何任务", vim.log.levels.WARN)
		return
	end

	-- 过滤任务
	local filtered_tasks = task_filter.filter(all_tasks)
	if #filtered_tasks == 0 then
		vim.notify("当前无符合条件的任务", vim.log.levels.WARN)
		return
	end

	local items = {}
	local task_map = {}
	for _, task in ipairs(filtered_tasks) do
		table.insert(items, task.name)
		task_map[task.name] = task
	end

	vim.ui.select(items, {
		prompt = "选择要添加到队列的任务:",
	}, function(choice)
		if not choice then
			return
		end
		local task = task_map[choice]
		M.enqueue_task(task)
	end)
end

--- 执行队列中的所有任务（串行）
function M.execute_all()
	local tasks = queue.all()
	if #tasks == 0 then
		vim.notify("任务队列为空", vim.log.levels.WARN)
		return
	end

	local ok, err = runner.run(tasks)
	if ok then
		vim.notify("✅ 所有队列任务执行成功")
		queue.clear()
	else
		vim.notify("❌ 队列任务执行失败: " .. err, vim.log.levels.ERROR)
	end
end

--- 展示任务队列并进行操作
function M.manage_queue()
	local tasks = queue.all()
	if #tasks == 0 then
		vim.notify("当前任务队列为空", vim.log.levels.INFO)
		return
	end

	local items = {}
	for i, task in ipairs(tasks) do
		table.insert(items, string.format("[%d] %s", i, task.name))
	end

	vim.ui.select(items, {
		prompt = "任务队列:",
	}, function(choice, idx)
		if not choice then
			return
		end

		vim.ui.select({ "上移", "下移", "删除", "查看详情" }, {
			prompt = "操作: " .. choice,
		}, function(op)
			if op == "上移" then
				queue.move_up(idx)
			elseif op == "下移" then
				queue.move_down(idx)
			elseif op == "删除" then
				queue.remove(idx)
			elseif op == "查看详情" then
				show_task_preview(tasks[idx])
			end
		end)
	end)
end

return M
