local M = {
	nav_stack = {},
	root_tasks = {},
}

-- UI层级类型定义
M.LAYER_TYPES = {
	TASK_LIST = "task_list", -- 根任务列表
	FRAME_BRICK = "frame_brick", -- 积木框架（包含基础积木）
	BASE_BRICK = "base_brick", -- 基础积木（包含参数值）
	VALUE = "value", -- 参数值
}

function M.init(tasks)
	M.root_tasks = tasks
	M.nav_stack = {
		{
			parent = nil,
			current = tasks,
			selected_index = 1,
			type = M.LAYER_TYPES.TASK_LIST,
		},
	}
end

function M.current_layer()
	return M.nav_stack[#M.nav_stack]
end

function M.get_nav_stack()
	return M.nav_stack
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

	if current.type == M.LAYER_TYPES.TASK_LIST then
		-- 进入任务 -> 展示积木框架
		if selected.type == "frame" then
			-- 框架积木：显示其基础积木
			local base_bricks = {}

			if selected.frame and type(selected.frame) == "table" then
				for param, value in pairs(selected.frame) do
					table.insert(base_bricks, {
						name = param,
						value = value,
						type = M.LAYER_TYPES.BASE_BRICK,
					})
				end
			end

			-- 添加依赖任务
			if selected.deps then
				for _, dep_name in ipairs(selected.deps) do
					for _, task in ipairs(M.root_tasks) do
						if task.name == dep_name then
							table.insert(base_bricks, {
								name = task.name,
								value = task,
								type = M.LAYER_TYPES.TASK_LIST,
								is_dependency = true,
							})
							break
						end
					end
				end
			end

			table.insert(M.nav_stack, {
				parent = current,
				current = base_bricks,
				selected_index = 1,
				type = M.LAYER_TYPES.FRAME_BRICK,
				source_task = selected,
			})
		else
			-- 非框架积木直接展示其参数
			local values = {}

			if selected[selected.type] then
				for param, value in pairs(selected[selected.type]) do
					table.insert(values, {
						name = param,
						value = value,
						type = M.LAYER_TYPES.BASE_BRICK,
					})
				end
			end

			if #values > 0 then
				table.insert(M.nav_stack, {
					parent = current,
					current = values,
					selected_index = 1,
					type = M.LAYER_TYPES.BASE_BRICK,
					source_task = selected,
				})
			end
		end
	elseif current.type == M.LAYER_TYPES.FRAME_BRICK then
		-- 积木框架 -> 展示基础积木的参数值
		if selected.type == M.LAYER_TYPES.BASE_BRICK then
			-- 基础积木 -> 展示参数值
			if type(selected.value) == "table" then
				local values = {}
				if vim.tbl_islist(selected.value) then
					-- 数组值
					for _, v in ipairs(selected.value) do
						table.insert(values, {
							value = v,
							type = M.LAYER_TYPES.VALUE,
						})
					end
				else
					-- 字典值
					for k, v in pairs(selected.value) do
						table.insert(values, {
							name = k,
							value = v,
							type = M.LAYER_TYPES.VALUE,
						})
					end
				end

				table.insert(M.nav_stack, {
					parent = current,
					current = values,
					selected_index = 1,
					type = M.LAYER_TYPES.BASE_BRICK,
					source_brick = selected,
				})
			else
				-- 简单值直接显示
				table.insert(M.nav_stack, {
					parent = current,
					current = {
						{
							value = selected.value,
							type = M.LAYER_TYPES.VALUE,
						},
					},
					selected_index = 1,
					type = M.LAYER_TYPES.BASE_BRICK,
					source_brick = selected,
				})
			end
		elseif selected.type == M.LAYER_TYPES.TASK_LIST then
			-- 依赖任务 -> 进入该任务的积木框架
			M.navigate_into() -- 递归处理
		end
	elseif current.type == M.LAYER_TYPES.BASE_BRICK then
		-- 参数值层级不再深入
		return
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
