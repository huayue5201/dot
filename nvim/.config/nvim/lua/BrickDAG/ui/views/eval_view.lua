local M = {}

local function render_table(tbl, indent)
	local lines = {}
	indent = indent or ""

	if vim.tbl_islist(tbl) then
		for _, v in ipairs(tbl) do
			if type(v) == "table" then
				v = vim.inspect(v)
			end
			table.insert(lines, indent .. "- " .. tostring(v))
		end
	else
		for k, v in pairs(tbl) do
			if type(v) == "table" then
				if vim.tbl_islist(v) then
					table.insert(lines, indent .. k .. ":")
					vim.list_extend(lines, render_table(v, indent .. "  "))
				else
					table.insert(lines, indent .. k .. ": " .. vim.inspect(v))
				end
			else
				table.insert(lines, indent .. k .. ": " .. tostring(v))
			end
		end
	end

	return lines
end

function M.render(buf, data)
	local layer = data.layer or {}
	local item = data.item
	local lines = {}

	if not item then
		table.insert(lines, "> 选择项目查看详情")
	elseif layer.type == "task_list" then
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

		-- 显示任务参数
		if item.type and item[item.type] then
			table.insert(lines, "")
			table.insert(lines, "参数:")
			vim.list_extend(lines, render_table(item[item.type], "  "))
		end
	elseif layer.type == "field_list" then
		table.insert(lines, "# 字段详情")
		table.insert(lines, "字段: " .. tostring(item))
		table.insert(lines, "所属任务: " .. layer.task.name)
	elseif layer.type == "value_list" then
		table.insert(lines, "# 值详情")
		table.insert(lines, "字段: " .. layer.field)

		if type(item) == "table" then
			vim.list_extend(lines, render_table(item))
		else
			table.insert(lines, "值: " .. tostring(item))
		end
	else
		table.insert(lines, "> 未知类型")
	end

	if #lines == 0 then
		table.insert(lines, "> 无详情内容")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
