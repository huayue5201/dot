-- lua/todo/core/sync.lua
local M = {}

---------------------------------------------------------------------
-- 父子任务联动
---------------------------------------------------------------------
function M.sync_parent_child_state(tasks, bufnr)
	local changed = false

	for _, task in ipairs(tasks) do
		if #task.children > 0 then
			-- 确保有统计信息
			if not task.stats then
				local stats_module = require("todo2.core.stats")
				stats_module.calculate_all_stats({ task })
			end

			local stats = task.stats
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

---------------------------------------------------------------------
-- 刷新函数（集成解析、统计、同步）
---------------------------------------------------------------------
function M.refresh(bufnr, core_module)
	local parser = require("todo2.core.parser")
	local stats = require("todo2.core.stats")
	local sync = require("todo2.core.sync")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = parser.parse_tasks(lines)

	-- 只计算一次统计
	stats.calculate_all_stats(tasks)

	-- 同步父子状态，如果需要重新计算，则重新计算
	if sync.sync_parent_child_state(tasks, bufnr) then
		-- 如果有父任务状态改变，重新解析并计算
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		tasks = parser.parse_tasks(lines)
		stats.calculate_all_stats(tasks)
	end

	local roots = parser.get_root_tasks(tasks)

	-- 渲染（通过回调，因为渲染在另一个模块）
	if core_module and core_module.render then
		core_module.render.render_all(bufnr, roots)
	end

	return tasks
end

return M
