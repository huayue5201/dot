local M = {}
-- 切换任务状态
function M.toggle_task_state()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()

	local options = {
		{ display = "󰄱 待完成", symbol = "[ ]" },
		{ display = "󰱒 完成", symbol = "[x]" },
		{ display = " 搁置", symbol = "[-]" },
		{ display = " 待定", symbol = "[~]" },
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
					local new_line = line:sub(1, start_idx - 1) .. choice.symbol .. line:sub(end_idx + 1)
					vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
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
