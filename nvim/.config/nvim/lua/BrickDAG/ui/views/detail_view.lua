local M = {}

function M.render(buf, data)
	if not data then
		return
	end

	local lines = {}

	-- 显示积木信息
	if data.brick then
		table.insert(lines, "积木: " .. data.brick)
		table.insert(lines, "")
		table.insert(lines, "类型: " .. (data.brick_type or "任务"))

		-- 添加积木描述（如果有）
		if data.description then
			table.insert(lines, "")
			table.insert(lines, "描述: " .. data.description)
		end

		-- 添加积木参数（如果有）
		if data.parameters then
			table.insert(lines, "")
			table.insert(lines, "参数:")
			for _, param in ipairs(data.parameters) do
				table.insert(lines, "  " .. param)
			end
		end

	-- 显示积木参数值
	elseif data.item and data.item.value then
		local value = data.item.value

		-- 处理简单值
		if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
			table.insert(lines, tostring(value))
		-- 处理数组
		elseif type(value) == "table" and #value > 0 then
			for _, v in ipairs(value) do
				table.insert(lines, tostring(v))
			end
		-- 处理键值对
		elseif type(value) == "table" then
			for _, v in pairs(value) do
				if type(v) == "table" then
					for _, subv in ipairs(v) do
						table.insert(lines, tostring(subv))
					end
				else
					table.insert(lines, tostring(v))
				end
			end
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
