local M = {}

-- 切换任务状态
local namespace = vim.api.nvim_create_namespace("task_timestamp_highlight")

-- 高亮标签+时间戳
function M.highlight_timestamp()
	vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	for i, line in ipairs(lines) do
		local s, e = line:find("%s+%a+:%d%d%d%d%-%d%d%-%d%d %d%d:%d%d")
		if s and e then
			vim.api.nvim_buf_set_extmark(0, namespace, i - 1, s - 1, {
				end_col = e,
				hl_group = "TaskTimestamp",
				priority = 100,
			})
		end
	end
end

-- 设置高亮样式
vim.api.nvim_set_hl(0, "TaskTimestamp", {
	fg = "#888888",
	italic = true,
})

-- 自动命令：保存或移动光标时刷新高亮
vim.api.nvim_create_autocmd({ "BufReadPost", "InsertEnter" }, {
	callback = function()
		M.highlight_timestamp()
	end,
})

-- 切换任务状态并更新标签+时间戳
function M.toggle_task_state()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()

	local options = {
		{ display = "󰄱 待完成", symbol = "[ ]", label = "todo" },
		{ display = "󰱒 完成", symbol = "[x]", label = "done" },
		{ display = " 搁置", symbol = "[-]", label = "postponed" },
		{ display = " 待定", symbol = "[~]", label = "pending" },
	}

	vim.ui.select(options, {
		prompt = "选择任务状态",
		format_item = function(item)
			return item.display
		end,
	}, function(choice)
		if choice then
			for _, state in ipairs({ "[ ]", "[x]", "[-]", "[~]" }) do
				local start_idx, end_idx = line:find(state, 1, true)
				if start_idx then
					local timestamp = os.date(":%Y-%m-%d %H:%M")
					local new_line = line:sub(1, start_idx - 1) .. choice.symbol .. line:sub(end_idx + 1)

					-- 去除旧标签+时间戳
					new_line = new_line:gsub("%s+%a+:%d%d%d%d%-%d%d%-%d%d %d%d:%d%d", "")

					-- 添加新标签+时间戳
					new_line = new_line .. " " .. choice.label .. timestamp

					vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
					-- 更新高亮
					M.highlight_timestamp()
					return
				end
			end
		end
	end)
end

-- 打开或新建 todo.md 文件（支持浮动窗口或常规窗口）
function M.open_or_create_todo_file(floating)
	local root = vim.fn.getcwd() -- 项目根目录
	local todo_path = root .. "/todo.md"

	-- 如果文件不存在，询问是否创建
	if vim.fn.filereadable(todo_path) == 0 then
		local answer = vim.fn.input(" 当前项目没有  todo 文件，是否创建？(y/n): ")
		if answer:lower() ~= "y" then
			print("取消创建 todo 文件。")
			return
		end

		-- 用户同意创建文件
		local fd = io.open(todo_path, "w")
		if fd then
			fd:write("# A list of tasks Launch  \n\n")
			fd:close()
			print("创建了新文件: " .. todo_path)
		else
			print("无法创建文件: " .. todo_path)
			return
		end
	end

	-- 文件存在或刚创建，打开文件
	if floating then
		local width = 80
		local height = 20
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			col = math.floor((vim.o.columns - width) / 2),
			row = math.floor((vim.o.lines - height) / 2),
			border = "rounded",
			title = " 󱑆 TODO清单 ",
			style = "minimal",
		})
		vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
	else
		vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
	end
end

-- 插入一个新任务项
function M.new_task_item()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local indent = vim.fn.indent(row)

	local line = string.rep(" ", indent) .. "- [ ]  "
	vim.api.nvim_buf_set_lines(0, row, row, true, { line })
	vim.api.nvim_win_set_cursor(0, { row + 1, #line })
	vim.cmd("startinsert")
end

return M
