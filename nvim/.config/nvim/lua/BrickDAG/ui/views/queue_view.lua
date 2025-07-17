local M = {}

function M.render(buf, data)
	local lines = {}

	if data.empty then
		-- 空队列状态
		table.insert(lines, "任务队列状态")
		table.insert(lines, "--------------")
		table.insert(lines, data.message)
		table.insert(lines, "")
		table.insert(lines, "按 'a' 添加当前任务到队列")

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 2, 0, -1)
		return
	end

	-- 显示队列内容
	table.insert(lines, "任务队列 (" .. data.count .. "个任务)")
	table.insert(lines, "-----------------------")

	for i, task in ipairs(data.tasks) do
		local prefix = (i == data.current_index) and "▶ " or "  "
		local status = (i == data.current_index) and "[运行中]" or "[等待]"

		table.insert(lines, prefix .. i .. ". " .. task.name .. " " .. status)
	end

	-- 添加控制提示
	table.insert(lines, "")
	table.insert(lines, "控制: [s]开始 [x]清除 [d]删除")

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- 高亮当前任务
	if data.current_index > 0 then
		vim.api.nvim_buf_add_highlight(
			buf,
			-1,
			"Visual",
			data.current_index + 1, -- +1 跳过标题行
			0,
			-1
		)
	end
end

return M
