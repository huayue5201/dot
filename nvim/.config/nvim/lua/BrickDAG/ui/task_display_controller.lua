local state = require("BrickDAG.ui.state")
local decomposer = require("BrickDAG.utils.task_decomposer")
local ctx = require("BrickDAG.ui.tri_window_context")

local M = {}

function M.render_navigation()
	local nav_stack = state.get_nav_stack()
	local current_layer = nav_stack.layers[nav_stack.index]

	if not current_layer then
		return
	end

	-- 左侧窗口：父级任务（如果存在）
	local left_view = nil
	if current_layer.parent then
		left_view = {
			type = "task_list",
			data = current_layer.parent,
			selected_index = nil, -- 父级不显示选中状态
		}
	end

	-- 中间窗口：当前任务
	local center_view = {
		type = "task_list",
		data = current_layer.current,
		selected_index = current_layer.selected_index,
	}

	-- 右侧窗口：积木详情
	local right_view = nil
	if #current_layer.current > 0 and current_layer.selected_index then
		local selected_task = current_layer.current[current_layer.selected_index]
		if selected_task then
			right_view = {
				type = "brick_detail",
				data = decomposer.decompose_task(selected_task),
			}
		end
	end

	-- 更新三窗口
	ctx.update_all({
		left = left_view,
		center = center_view,
		right = right_view,
	})
end

function M.navigate_into_task()
	local nav_stack = state.get_nav_stack()
	local current_layer = nav_stack.layers[nav_stack.index]

	if not current_layer then
		return
	end

	local selected_task = current_layer.current[current_layer.selected_index]
	if not selected_task then
		return
	end

	-- 获取任务的依赖（这里需要您根据实际任务结构实现）
	local dependencies = selected_task.deps or {}

	-- 构建新层级
	local new_layer = {
		parent = current_layer.current,
		current = dependencies,
		selected_index = 1,
	}

	state.push_layer(new_layer)
	M.render_navigation()
end

function M.navigate_back()
	if state.pop_layer() then
		M.render_navigation()
	end
end

function M.navigate_selection(direction)
	if state.update_selection(direction) then
		M.render_navigation()
	end
end

return M
