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

local function show_todo_floating_window(path)
	local width, height = 80, 20
	local buf = vim.api.nvim_create_buf(false, true)
	local lines = {}
	local fd = io.open(path, "r")
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
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

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
		show_todo_floating_window(todo_path)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
	end
end

local function get_all_todo_projects()
	local todo_root = vim.fn.expand("~/.todo-files")
	local handle = vim.loop.fs_scandir(todo_root)
	if not handle then
		return {}, "没有找到 ~/.todo-files 目录。"
	end

	local choices = {}
	local max_name_len = 0

	while true do
		local name, typ = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		local todo_path = todo_root .. "/" .. name .. "/todo.md"
		if typ == "directory" and vim.fn.filereadable(todo_path) == 1 then
			table.insert(choices, {
				label = "󰑉 " .. name,
				project = name,
				path = todo_path,
			})
			max_name_len = math.max(max_name_len, #name)
		end
	end

	if #choices == 0 then
		return {}, "没有可用的 todo 文件。"
	end

	return choices, nil, max_name_len
end

function M.select_and_open_todo_file(floating)
	local choices, err, max_len = get_all_todo_projects()
	if err then
		vim.notify(err, vim.log.levels.INFO)
		return
	end

	vim.ui.select(choices, {
		prompt = "选择要打开的 TODO 文件：",
		format_item = function(item)
			local name_fmt = string.format("%-" .. max_len .. "s", item.project)
			return string.format("󰑉 %s    %s", name_fmt, vim.fn.fnamemodify(item.path, ":~"))
		end,
	}, function(choice)
		if not choice then
			return
		end
		if floating then
			require("modules.todo.ui").open_todo_floating(choice.path)
		else
			vim.cmd("edit " .. vim.fn.fnameescape(choice.path))
		end
	end)
end

function M.delete_project_todo()
	local choices, err, max_len = get_all_todo_projects()
	if err then
		vim.notify(err, vim.log.levels.INFO)
		return
	end

	vim.ui.select(choices, {
		prompt = "选择要删除的 TODO 项目：",
		format_item = function(item)
			local name_fmt = string.format("%-" .. max_len .. "s", item.project)
			return string.format("󰑉 %s    %s", name_fmt, vim.fn.fnamemodify(item.path, ":~"))
		end,
	}, function(choice)
		if not choice then
			vim.notify("未选择任何项目文件夹", vim.log.levels.INFO)
			return
		end

		local confirm = vim.fn.input("确定要删除: " .. choice.project .. " 吗？(y/n): "):lower()
		if confirm == "y" then
			local delete_cmd = "rm -rf " .. vim.fn.fnameescape(vim.fn.expand("~/.todo-files/" .. choice.project))
			local result = vim.fn.system(delete_cmd)
			if vim.v.shell_error == 0 then
				vim.notify("成功删除项目: " .. choice.project, vim.log.levels.INFO)
			else
				vim.notify("删除失败: " .. result, vim.log.levels.ERROR)
			end
		else
			vim.notify("取消删除项目", vim.log.levels.INFO)
		end
	end)
end

-- 将普通文本转化为任务行
function M.convert_line_to_task()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	-- 如果已经是任务行，退出
	if line:match("^%s*%- %[[ xX%-~]%]") then
		vim.notify("当前行已经是任务。", vim.log.levels.INFO)
		return
	end
	local indent = line:match("^%s*") or ""
	local content = line:match("^%s*(.-)%s*$")
	-- 剔除前缀符号：如 "* ", "- ", "• ", "+ ", "1. " 等项目列表符号
	content = content:gsub("^[-*•+%d+%.%s]+", "")
	local new_line = indent .. "- [ ] " .. content
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
	vim.api.nvim_win_set_cursor(0, { row, #new_line })
end

-- 在当前行插入新任务项
function M.new_task_item()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local indent = vim.fn.indent(row) -- 获取当前行的缩进
	local line = string.rep(" ", indent) .. "- [ ]  " -- 创建新任务行
	-- 在当前行插入新任务项
	vim.api.nvim_buf_set_lines(0, row, row, true, { line })
	-- 将光标移到新插入的任务行
	vim.api.nvim_win_set_cursor(0, { row + 1, #line + 1 })
	-- 延迟执行插入模式，以确保光标已经更新
	vim.defer_fn(function()
		vim.cmd("startinsert")
	end, 10) -- 延迟 10ms 进入插入模式
end

return M
