local M = {}

function M.render(buf, data)
	local items = data.items or {}
	local selected_index = data.selected_index or 1
	local layer_type = data.layer_type or "task_list"

	local lines = {}
	local highlights = {}

	for i, item in ipairs(items) do
		local prefix = (i == selected_index) and "> " or "  "
		local icon = "○"
		local text = item.name or ""
		local indicator = ""

		-- 任务列表图标
		if layer_type == "task_list" then
			icon = "󰄾" -- 任务图标

			-- 积木参数指示器
			if item.type and item[item.type] then
				indicator = " [◈]"
			end

			-- 依赖指示器
			if item.deps and #item.deps > 0 then
				indicator = indicator .. " [←]"
			end
		end

		-- 积木列表图标
		if layer_type == "brick_list" then
			if item.brick_type == "param" then
				icon = "" -- 参数图标
			elseif item.brick_type == "dep_task" then
				icon = "󰄾" -- 依赖任务图标
				indicator = " [←]"
			end
		end

		table.insert(lines, prefix .. icon .. " " .. text .. indicator)

		if i == selected_index then
			table.insert(highlights, { line = i - 1, hl = "Visual" })
		end
	end

	if #lines == 0 then
		table.insert(lines, "> 无内容")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(buf, -1, hl.hl, hl.line, 0, -1)
	end

	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
