-- UI管理器 (ui_manager.lua)

local M = {}

local ns_id = vim.api.nvim_create_namespace("TaskMasterInputForm")

function M.show_task_picker(tasks, callback)
	local items = {}
	for id, task in pairs(tasks) do
		table.insert(items, {
			label = string.format("%s: %s", id, task.label),
			id = id,
		})
	end

	table.sort(items, function(a, b)
		return a.id < b.id
	end)

	local labels = {}
	for _, item in ipairs(items) do
		table.insert(labels, item.label)
	end

	vim.ui.select(labels, {
		prompt = "请选择任务:",
		format_item = function(item)
			return item
		end,
	}, function(choice, index)
		if choice and index then
			callback(items[index].id)
		else
			callback(nil)
		end
	end)
end

function M.show_priority_picker(callback)
	local priorities = {
		{ value = 1, label = "🚀 P1: 最高优先级 (紧急任务)" },
		{ value = 2, label = "🔥 P2: 高优先级 (重要任务)" },
		{ value = 3, label = "🔥 P3: 高优先级 (重要任务)" },
		{ value = 4, label = "⚡ P4: 中优先级 (常规任务)" },
		{ value = 5, label = "⚡ P5: 中优先级 (常规任务)" },
		{ value = 6, label = "⚡ P6: 中优先级 (常规任务)" },
		{ value = 7, label = "⚡ P7: 中优先级 (常规任务)" },
		{ value = 8, label = "🐢 P8: 低优先级 (后台任务)" },
		{ value = 9, label = "🐢 P9: 低优先级 (后台任务)" },
		{ value = 10, label = "🐢 P10: 低优先级 (后台任务)" },
	}

	local labels = {}
	for _, p in ipairs(priorities) do
		table.insert(labels, p.label)
	end

	vim.ui.select(labels, {
		prompt = "请选择任务优先级:",
		format_item = function(item)
			return item
		end,
		default = 5,
	}, function(choice, index)
		if choice and index then
			callback(priorities[index].value)
		else
			callback(nil)
		end
	end)
end

function M.show_task_queue(queue, manager)
	local items = queue:get_queue_items()
	local options = {}

	if #items == 0 then
		table.insert(options, {
			label = "队列为空",
			action = "none",
		})
	else
		local priority_icons = {
			[1] = "🚀",
			[2] = "🔥",
			[3] = "🔥",
			[4] = "⚡",
			[5] = "⚡",
			[6] = "⚡",
			[7] = "⚡",
			[8] = "🐢",
			[9] = "🐢",
			[10] = "🐢",
		}

		for i, item in ipairs(items) do
			local icon = priority_icons[item.priority] or ""
			table.insert(options, {
				label = string.format("%s %2d. %-20s (优先级: %d)", icon, i, item.task.id, item.priority),
				index = i,
				task = item.task,
				priority = item.priority,
				item = item, -- 添加完整队列项引用
			})
		end
	end

	vim.ui.select(options, {
		prompt = "任务队列:",
		format_item = function(option)
			return option.label
		end,
	}, function(selected)
		if not selected then
			return
		end
		if selected.action == "none" then
			return
		end

		-- 修改操作菜单，添加"任务详情"选项
		vim.ui.select({ "立即执行", "删除任务", "调整优先级", "任务详情" }, {
			prompt = "选择操作:",
			format_item = function(action)
				return action
			end,
		}, function(action)
			if not action then
				return
			end

			if action == "立即执行" then
				manager:run_task(selected.task.id)
			elseif action == "删除任务" then
				queue:remove(selected.task.id)
				vim.notify("任务已从队列中删除: " .. selected.task.id)
				M.show_task_queue(queue, manager)
			elseif action == "调整优先级" then
				M.show_priority_picker(function(new_priority)
					if new_priority then
						queue:update_priority(selected.task.id, new_priority)
						vim.notify(
							string.format(
								"任务 '%s' 优先级已更新: %d → %d",
								selected.task.id,
								selected.priority,
								new_priority
							)
						)
						M.show_task_queue(queue, manager)
					end
				end)
			elseif action == "任务详情" then
				M.show_task_details(selected.item.task, manager.repository)
			end
		end)
	end)
end

function M.show_task_history(queue)
	local history = queue:get_history()
	local items = {}

	if #history == 0 then
		table.insert(items, "暂无历史记录")
	else
		for i, entry in ipairs(history) do
			local status_icon = entry.status == "completed" and "✅" or "❌"
			table.insert(
				items,
				string.format(
					"%s %s: %s (%.1fs) - %s",
					status_icon,
					os.date("%H:%M", entry.start_time),
					entry.task.id,
					entry.duration,
					entry.status
				)
			)
		end
	end

	vim.ui.select(items, {
		prompt = "任务执行历史:",
		format_item = function(item)
			return item
		end,
	}, function(choice, index)
		if choice and index and #history > 0 then
			local entry = history[index]
			M.show_task_output(entry.output, "历史输出: " .. entry.task.id)
		end
	end)
end

function M.show_task_output(output, title)
	output = output or { "没有输出" }

	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = title or "任务输出",
		title_pos = "center",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })

	vim.keymap.set("n", "<ESC>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })

	return win
end

function M.show_input_form(fields, callback)
	local form_buf = vim.api.nvim_create_buf(false, true)
	local width = 60
	local height = #fields + 4
	local win = vim.api.nvim_open_win(form_buf, true, {
		relative = "cursor",
		width = width,
		height = height,
		row = 1,
		col = 0,
		style = "minimal",
		border = "rounded",
		title = "任务参数",
		title_pos = "center",
	})

	local lines = {}
	local field_lines = {}
	for i, field in ipairs(fields) do
		table.insert(lines, field.label .. ":")
		table.insert(lines, "")
		field_lines[field.field] = i * 2
	end

	vim.api.nvim_buf_set_lines(form_buf, 0, -1, false, lines)

	for _, field in ipairs(fields) do
		local row = field_lines[field.field]
		vim.api.nvim_buf_set_extmark(form_buf, ns_id, row - 1, 0, {
			virt_text = { { field.default, "Comment" } },
			virt_text_pos = "overlay",
		})
	end

	local results = {}
	vim.keymap.set("n", "<CR>", function()
		for _, field in ipairs(fields) do
			local row = field_lines[field.field]
			local line = vim.api.nvim_buf_get_lines(form_buf, row - 1, row, false)[1]
			results[field.field] = line ~= "" and line or field.default
		end
		vim.api.nvim_win_close(win, true)
		callback(results)
	end, { buffer = form_buf })

	vim.keymap.set("n", "<ESC>", function()
		vim.api.nvim_win_close(win, true)
		callback(nil)
	end, { buffer = form_buf })

	vim.api.nvim_set_current_win(win)
	vim.api.nvim_win_set_cursor(win, { field_lines[fields[1].field], 0 })
end

function M.show_task_details(task, repository)
	-- 获取任务的完整信息（包括仓库中的默认值）
	local full_task = repository:get_task_by_id(task.id)
	if not full_task then
		vim.notify("无法找到任务详情: " .. task.id, vim.log.levels.ERROR)
		return
	end

	-- 合并任务定义和队列项中的参数
	local merged_task = vim.deepcopy(full_task)
	if task.params then
		merged_task.params = vim.tbl_extend("force", merged_task.params or {}, task.params)
	end

	-- 创建任务详情内容
	local lines = {
		"任务详情: " .. merged_task.id,
		"----------------------------------------",
		string.format("标签: %s", merged_task.label or "无"),
		string.format("描述: %s", merged_task.description or "无"),
		"",
	}

	-- 添加参数信息
	table.insert(lines, "参数:")
	if merged_task.params and next(merged_task.params) then
		for key, value in pairs(merged_task.params) do
			table.insert(lines, string.format("  %s = %s", key, tostring(value)))
		end
	else
		table.insert(lines, "  无参数")
	end
	table.insert(lines, "")

	-- 添加环境变量信息
	table.insert(lines, "环境变量:")
	if merged_task.env and next(merged_task.env) then
		for key, value in pairs(merged_task.env) do
			table.insert(lines, string.format("  %s = %s", key, tostring(value)))
		end
	else
		table.insert(lines, "  无自定义环境变量")
	end
	table.insert(lines, "")

	-- 添加其他元数据
	table.insert(lines, "元数据:")
	table.insert(lines, string.format("  超时: %s 秒", merged_task.timeout or "无"))
	table.insert(
		lines,
		string.format(
			"  依赖任务: %s",
			merged_task.depends_on and table.concat(merged_task.depends_on, ", ") or "无"
		)
	)
	table.insert(lines, "")

	-- 添加命令预览
	table.insert(lines, "命令预览:")
	if type(merged_task.cmd) == "function" then
		local cmd_result = merged_task.cmd(merged_task.params)
		if type(cmd_result) == "table" then
			for _, cmd_line in ipairs(cmd_result) do
				table.insert(lines, "  " .. cmd_line)
			end
		else
			table.insert(lines, "  " .. tostring(cmd_result))
		end
	else
		table.insert(lines, "  " .. tostring(merged_task.cmd))
	end

	-- 创建浮动窗口
	local width = math.floor(vim.o.columns * 0.7)
	local height = math.min(#lines + 4, math.floor(vim.o.lines * 0.8))
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = "任务详情: " .. merged_task.id,
		title_pos = "center",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	-- 设置语法高亮
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	-- 添加关闭映射
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })

	vim.keymap.set("n", "<ESC>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })

	-- 添加复制命令映射
	vim.keymap.set("n", "yy", function()
		local line = vim.api.nvim_get_current_line()
		vim.fn.setreg('"', line)
		vim.notify("已复制: " .. line, vim.log.levels.INFO)
	end, { buffer = buf, nowait = true })

	return win
end

function M.show_action_picker(actions, callback)
	local labels = {}
	for _, action in ipairs(actions) do
		table.insert(labels, action.label)
	end

	vim.ui.select(labels, {
		prompt = "TaskMaster:",
		format_item = function(item)
			return item
		end,
	}, function(choice, index)
		if choice and index then
			callback(actions[index].id)
		else
			callback(nil)
		end
	end)
end

function M.show_env_manager(global_env)
	local buf = vim.api.nvim_create_buf(false, true)
	local lines = { "# 环境变量管理", "" }

	for k, v in pairs(global_env) do
		-- 确保值中没有换行符
		local safe_value = tostring(v):gsub("\n", "\\n")
		table.insert(lines, string.format("%s=%s", k, safe_value))
	end

	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.7)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = "环境变量",
		title_pos = "center",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)

	vim.keymap.set("n", "<leader>s", function()
		local new_lines = vim.api.nvim_buf_get_lines(buf, 2, -1, false)
		local new_env = {}

		-- 处理换行符问题
		local processed_lines = {}
		for _, line in ipairs(new_lines) do
			for sub_line in line:gmatch("[^\n]+") do
				table.insert(processed_lines, sub_line)
			end
		end

		for _, line in ipairs(processed_lines) do
			if line:find("=") then
				local k, v = line:match("([^=]+)=(.*)")
				if k and v then
					-- 还原转义的换行符
					new_env[k] = v:gsub("\\n", "\n")
				end
			end
		end
		global_env = new_env
		vim.api.nvim_win_close(win, true)
		vim.notify("环境变量已更新")
	end, { buffer = buf })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf })
end

return M
