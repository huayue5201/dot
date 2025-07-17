local M = {}

--- 格式化 value 为展示行
local function format_value(value, indent)
	local lines = {}
	indent = indent or ""

	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		table.insert(lines, indent .. tostring(value))
	elseif type(value) == "table" then
		if vim.tbl_islist(value) then
			-- 数组
			for _, v in ipairs(value) do
				if type(v) == "table" then
					table.insert(lines, indent .. "- " .. vim.inspect(v))
				else
					table.insert(lines, indent .. "- " .. tostring(v))
				end
			end
		else
			-- 字典
			for k, v in pairs(value) do
				if type(v) == "table" then
					table.insert(lines, indent .. k .. ":")
					vim.list_extend(lines, format_value(v, indent .. "  "))
				else
					table.insert(lines, indent .. k .. ": " .. tostring(v))
				end
			end
		end
	else
		table.insert(lines, indent .. vim.inspect(value))
	end

	return lines
end

function M.render(buf, data)
	if not data then
		return
	end

	local lines = {}

	-- 显示积木（任务）信息
	if data.brick then
		table.insert(lines, "积木: " .. data.brick)
		table.insert(lines, "")
		table.insert(lines, "类型: " .. (data.brick_type or "任务"))

		if data.description then
			table.insert(lines, "")
			table.insert(lines, "描述: " .. data.description)
		end

		if data.parameters then
			table.insert(lines, "")
			table.insert(lines, "参数:")
			for _, param in ipairs(data.parameters) do
				table.insert(lines, "  " .. param)
			end
		end
	elseif data.item and data.item.value then
		local value = data.item.value
		vim.list_extend(lines, format_value(value))
	end

	if #lines == 0 then
		table.insert(lines, "> 无详情可展示")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
