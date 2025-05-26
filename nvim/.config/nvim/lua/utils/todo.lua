local M = {}

-- 命名空间用于高亮标签+时间戳
local namespace = vim.api.nvim_create_namespace("task_timestamp_highlight")

-- 常用任务复选框的正则表达式
local checkbox_patterns = { "%[ %]", "%[x%]", "%[%-%]", "%[~%]" }

-- 高亮任务状态标签后的时间戳（如 done:2025-05-26 12:00）
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

-- 自动刷新时间戳高亮
vim.api.nvim_create_autocmd({ "BufReadPost", "InsertEnter" }, {
	callback = function()
		M.highlight_timestamp()
	end,
})

-- 切换任务状态并插入标签+时间戳
local function line_has_checkbox(line)
	for _, pattern in ipairs(checkbox_patterns) do
		if line:find(pattern) then
			return true
		end
	end
	return false
end

function M.toggle_task_state()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()

	if not line_has_checkbox(line) then
		print("当前行没有任务复选框，无法切换状态。")
		return
	end

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
		if not choice then
			return
		end

		local checkbox_start, checkbox_end
		for _, symbol in ipairs(checkbox_patterns) do
			checkbox_start, checkbox_end = line:find(symbol)
			if checkbox_start then
				break
			end
		end

		if not checkbox_start then
			return
		end

		local timestamp = os.date(":%Y-%m-%d %H:%M")
		local new_line = line:sub(1, checkbox_start - 1) .. choice.symbol .. line:sub(checkbox_end + 1)

		-- 移除旧时间戳和旧状态标签
		new_line = new_line:gsub("%s+%a+:%d%d%d%d%-%d%d%-%d%d %d%d:%d%d", "")
		new_line = new_line:gsub("%s*(todo|done|postponed|pending)", "")
		new_line = new_line .. " " .. choice.label .. timestamp

		vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
		M.highlight_timestamp()
	end)
end

-- 获取当前项目名
local function get_project_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 统计任务数量
local function get_task_summary(lines)
	local stat = { todo = 0, done = 0, postponed = 0, pending = 0 }
	for _, line in ipairs(lines) do
		if line:match("%[ %]") then
			stat.todo = stat.todo + 1
		end
		if line:match("%[x%]") then
			stat.done = stat.done + 1
		end
		if line:match("%[%-%]") then
			stat.postponed = stat.postponed + 1
		end
		if line:match("%[~%]") then
			stat.pending = stat.pending + 1
		end
	end
	return stat
end

-- 打开/创建 todo 文件，支持浮窗或常规打开
function M.open_or_create_todo_file(floating)
	local project = get_project_name()
	local todo_dir = vim.fn.expand("~/.todo-files/" .. project)
	local todo_path = todo_dir .. "/todo.md"

	if vim.fn.filereadable(todo_path) == 0 then
		if vim.fn.input(" 当前项目没有  todo 文件，是否创建？(y/n): "):lower() ~= "y" then
			print("取消创建 todo 文件。")
			return
		end
		vim.fn.mkdir(todo_dir, "p")
		local fd = io.open(todo_path, "w")
		if fd then
			fd:write("# TODO - " .. project .. "\n\n")
			fd:close()
			print("创建了新文件: " .. todo_path)
		else
			print("无法创建文件: " .. todo_path)
			return
		end
	end

	if floating then
		local width, height = 80, 20
		local buf = vim.api.nvim_create_buf(false, true)

		local lines = {}
		local fd = io.open(todo_path, "r")
		if fd then
			for line in fd:lines() do
				table.insert(lines, line)
			end
			fd:close()
		end

		local stat = get_task_summary(lines)
		local summary = string.format(
			"󰄱 %d  󰱒 %d   %d   %d   总计: %d",
			stat.todo,
			stat.done,
			stat.postponed,
			stat.pending,
			stat.todo + stat.done + stat.postponed + stat.pending
		)

		vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			col = math.floor((vim.o.columns - width) / 2),
			row = math.floor((vim.o.lines - height) / 2),
			border = "rounded",
			title = " 󱑆 TODO清单 ",
			style = "minimal",
			footer = { { " " .. summary .. " ", "Number" } },
			footer_pos = "right",
		})
		vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
	else
		vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
	end
end

-- 删除指定项目的 todo 文件夹
function M.delete_project_todo()
	local todo_base_dir = vim.fn.expand("~/.todo-files/")

	-- 获取 todo 目录下所有的项目文件夹
	local dirs = {}
	for _, file in ipairs(vim.fn.readdir(todo_base_dir)) do
		local dir_path = todo_base_dir .. file
		if vim.fn.isdirectory(dir_path) == 1 then
			table.insert(dirs, dir_path)
		end
	end

	-- 如果没有找到项目文件夹，提示并返回
	if #dirs == 0 then
		vim.notify("没有找到任何项目文件夹", vim.log.levels.INFO)
		return
	end

	-- 使用 vim.ui.select 列出项目并让用户选择
	vim.ui.select(dirs, {
		prompt = "选择要删除的项目文件夹: ",
		format_item = function(path)
			return vim.fn.fnamemodify(path, ":p:~") -- 格式化显示的路径
		end,
	}, function(choice)
		if choice then
			local confirm = vim.fn
				.input("确定要删除项目文件夹: " .. vim.fn.fnamemodify(choice, ":t") .. " 吗？(y/n): ")
				:lower()
			if confirm == "y" then
				local delete_cmd = "rm -rf " .. vim.fn.fnameescape(choice)
				local result = vim.fn.system(delete_cmd)
				if vim.v.shell_error == 0 then
					vim.notify("成功删除项目文件夹: " .. vim.fn.fnamemodify(choice, ":t"), vim.log.levels.INFO)
				else
					vim.notify("删除项目文件夹失败: " .. result, vim.log.levels.ERROR)
				end
			else
				vim.notify("取消删除项目文件夹", vim.log.levels.INFO)
			end
		else
			vim.notify("未选择任何项目文件夹", vim.log.levels.INFO)
		end
	end)
end

-- 插入新的任务项（缩进自动对齐）
function M.new_task_item()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local indent = vim.fn.indent(row)
	local line = string.rep(" ", indent) .. "- [ ]  "
	vim.api.nvim_buf_set_lines(0, row, row, true, { line })
	vim.api.nvim_win_set_cursor(0, { row + 1, #line })
	vim.cmd("startinsert")
end

return M
