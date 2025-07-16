local M = {
	nav_stack = {
		layers = {},
		index = 0,
	},
}

function M.init(root_tasks)
	M.nav_stack = {
		layers = {
			{
				parent = nil,
				current = root_tasks,
				selected_index = 1,
			},
		},
		index = 1,
	}
end

function M.get_nav_stack()
	return M.nav_stack
end

function M.push_layer(layer)
	M.nav_stack.index = M.nav_stack.index + 1
	M.nav_stack.layers[M.nav_stack.index] = layer
end

function M.pop_layer()
	if M.nav_stack.index > 1 then
		M.nav_stack.index = M.nav_stack.index - 1
		return true
	end
	return false
end

function M.get_current_layer()
	return M.nav_stack.layers[M.nav_stack.index]
end

function M.update_selection(direction)
	local layer = M.get_current_layer()
	if not layer then
		return
	end

	local new_index = layer.selected_index + direction
	if new_index >= 1 and new_index <= #layer.current then
		layer.selected_index = new_index
		return true
	end
	return false
end

return M
