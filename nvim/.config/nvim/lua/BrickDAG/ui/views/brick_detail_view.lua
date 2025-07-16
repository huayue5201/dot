local M = {}

function M.render(buf, context)
	-- 确保缓冲区可修改
	if not vim.api.nvim_buf_get_option(buf, "modifiable") then
		vim.api.nvim_buf_set_option(buf, "modifiable", true)
	end

	-- 清空缓冲区
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

	local lines = {}

	if context.data and context.data.brick then
		local brick = context.data.brick

		-- 积木基本信息
		table.insert(lines, "# " .. brick.title)
		table.insert(lines, "")
		table.insert(lines, "描述: " .. (brick.description or "无"))
		table.insert(lines, "")
		table.insert(lines, "状态: " .. (brick.status or "未开始"))
		table.insert(lines, "")
		table.insert(lines, "分解:")

		-- 递归函数：按顺序展开积木分解
		local function add_components(components, indent)
			for _, comp in ipairs(components) do
				-- 添加当前组件
				table.insert(lines, indent .. "• " .. comp.title)

				-- 如果有子组件，递归添加
				if comp.components and #comp.components > 0 then
					add_components(comp.components, indent .. "  ")
				end
			end
		end

		-- 添加积木分解部分
		if brick.components and #brick.components > 0 then
			add_components(brick.components, "  ")
		else
			table.insert(lines, "  无分解内容")
		end

		-- 添加备注信息
		if brick.notes and #brick.notes > 0 then
			table.insert(lines, "")
			table.insert(lines, "备注:")
			for _, note in ipairs(brick.notes) do
				table.insert(lines, "  • " .. note)
			end
		end
	else
		table.insert(lines, "无积木数据")
	end

	-- 设置内容到缓冲区
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- 设置只读
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "readonly", true)

	-- 设置文件类型
	vim.api.nvim_buf_set_option(buf, "filetype", "BrickDAGBrickDetail")
end

return M
