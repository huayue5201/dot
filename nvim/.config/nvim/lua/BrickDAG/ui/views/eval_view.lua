local M = {}

function M.render(buf, data)
	local layer = data.layer or {}
	local item = data.item
	local lines = {}

	if not item then
		table.insert(lines, "> 选择项目查看详情")
	elseif layer.type == "task_list" then
		-- 任务详情
		table.insert(lines, "# 任务详情")
		table.insert(lines, "名称: " .. item.name)
		table.insert(lines, "类型: " .. item.type)

		if item.deps and #item.deps > 0 then
			table.insert(lines, "依赖: " .. table.concat(item.deps, ", "))
		else
			table.insert(lines, "依赖: 无")
		end

		if item.description then
			table.insert(lines, "")
			table.insert(lines, "描述: " .. item.description)
		end
	elseif layer.type == "field_list" then
		-- 字段详情
		table.insert(lines, "# 字段详情")
		table.insert(lines, "字段: " .. tostring(item))
		table.insert(lines, "所属任务: " .. layer.task.name)
	elseif layer.type == "value_list" then
		-- 值详情
		table.insert(lines, "# 值详情")
		table.insert(lines, "字段: " .. layer.field)
		table.insert(lines, "值: " .. tostring(item))
	else
		table.insert(lines, "> 未知类型")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
