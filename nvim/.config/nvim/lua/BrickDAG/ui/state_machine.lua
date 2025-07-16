local M = {
	nav_stack = {},
	root_tasks = {},
}

function M.init(tasks)
	M.root_tasks = tasks
	M.nav_stack = {
		{
			parent = nil,
			current = tasks,
			selected_index = 1,
			type = "task_list",
		},
	}
end

function M.get_nav_stack()
	return M.nav_stack
end

function M.current_layer()
	return M.nav_stack[#M.nav_stack]
end

function M.navigate_into()
	local current = M.current_layer()
	if not current then
		return
	end

	local selected = current.current[current.selected_index]
	if not selected then
		return
	end

	-- 任务列表 -> 进入积木列表
	if current.type == "task_list" then
		local brick_list = {}

		-- 1. 查找积木参数
		if selected.type and selected[selected.type] then
			local brick_type = selected.type
			local brick_params = selected[brick_type]

			-- 将积木参数转换为任务格式
			for param, value in pairs(brick_params) do
				table.insert(brick_list, {
					name = param,
					value = value,
					brick_type = "param",
				})
			end
		end

		-- 2. 查找依赖任务
		if selected.deps then
			for _, dep_name in ipairs(selected.deps) do
				for _, task in ipairs(M.root_tasks) do
					if task.name == dep_name then
						task.brick_type = "dep_task" -- 标记为依赖任务
						table.insert(brick_list, task)
						break
					end
				end
			end
		end

		if #brick_list > 0 then
			table.insert(M.nav_stack, {
				parent = current,
				current = brick_list,
				selected_index = 1,
				type = "brick_list", -- 积木列表类型
				source_task = selected, -- 保存源任务
			})
		end
	end
end

function M.navigate_back()
	if #M.nav_stack > 1 then
		table.remove(M.nav_stack)
	end
end

function M.update_selection(delta)
	local layer = M.current_layer()
	if not layer then
		return
	end

	local new_index = layer.selected_index + delta
	if new_index >= 1 and new_index <= #layer.current then
		layer.selected_index = new_index
	end
end

return M
