local M = {}

-- 命名空间和样式
local ns = vim.api.nvim_create_namespace("task_timestamp_highlight")
vim.api.nvim_set_hl(0, "TaskTimestamp", { fg = "#888888", italic = true })

-- 常量定义
local CHECKBOX_PATTERNS = { "[ ]", "[x]", "[-]", "[~]" }
local STATE_LABELS = {
	todo = { symbol = "[ ]", display = "󰄱 待完成" },
	done = { symbol = "[x]", display = "󰱒 完成" },
	postponed = { symbol = "[-]", display = " 搁置" },
	pending = { symbol = "[~]", display = " 待定" },
}
local TIMESTAMP_PATTERN = "%s+%a+:%d%d%d%d%-%d%d%-%d%d %d%d:%d%d"

-- ⏱️ 高亮时间戳
function M.highlight_timestamp()
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local s, e = line:find(TIMESTAMP_PATTERN)
		if s then
			vim.api.nvim_buf_set_extmark(0, ns, i - 1, s - 1, {
				end_col = e,
				hl_group = "TaskTimestamp",
				priority = 100,
			})
		end
	end
end

vim.api.nvim_create_autocmd({ "BufReadPost", "InsertEnter" }, {
	callback = M.highlight_timestamp,
})

-- ✅ 判断是否含有任务复选框
local function has_checkbox(line)
	for _, pat in ipairs(CHECKBOX_PATTERNS) do
		if line:find("%" .. pat) then
			return true
		end
	end
	return false
end

-- ✅ 统计任务状态
local function summarize_tasks(lines)
	local count = { todo = 0, done = 0, postponed = 0, pending = 0 }
	for _, line in ipairs(lines) do
		for label, info in pairs(STATE_LABELS) do
			if line:match("%" .. info.symbol) then
				count[label] = count[label] + 1
			end
		end
	end
	return count
end

-- ✅ 构造状态摘要
local function format_summary(stat)
	return string.format(
		"󰄱 %d  󰱒 %d   %d   %d   总计: %d",
		stat.todo,
		stat.done,
		stat.postponed,
		stat.pending,
		stat.todo + stat.done + stat.postponed + stat.pending
	)
end

-- 📦 切换任务状态
function M.toggle_task_state()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	if not has_checkbox(line) then
		return vim.notify("当前行没有任务复选框，无法切换状态。", vim.log.levels.INFO)
	end

	local options = {}
	for key, info in pairs(STATE_LABELS) do
		table.insert(options, { key = key, display = info.display, symbol = info.symbol })
	end

	vim.ui.select(options, {
		prompt = "选择任务状态",
		format_item = function(item)
			return item.display
		end,
	}, function(choice)
		if not choice then
			return
		end
		local s, e = nil, nil
		for _, pat in ipairs(CHECKBOX_PATTERNS) do
			s, e = line:find(vim.pesc(pat))
			if s then
				break
			end
		end
		if not s then
			return
		end

		local new_line = line:sub(1, s - 1) .. choice.symbol .. line:sub(e + 1)
		new_line = new_line:gsub(TIMESTAMP_PATTERN, ""):gsub("%s*(todo|done|postponed|pending)", "")
			.. (" " .. choice.key .. os.date(":%Y-%m-%d %H:%M"))

		vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
		M.highlight_timestamp()
	end)
end

-- 📁 获取当前项目名
local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 🪟 显示浮动窗口
local function show_todo_floating(path)
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

	local summary = format_summary(summarize_tasks(lines))

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

-- 📄 打开或创建 TODO 文件
function M.open_or_create_todo_file(floating)
	local project = get_project()
	local dir = vim.fn.expand("~/.todo-files/" .. project)
	local path = dir .. "/todo.md"

	if vim.fn.filereadable(path) == 0 then
		if vim.fn.input(" 当前项目没有  todo 文件，是否创建？(y/n): "):lower() ~= "y" then
			return vim.notify("取消创建 todo 文件。", vim.log.levels.INFO)
		end
		vim.fn.mkdir(dir, "p")
		local fd = io.open(path, "w")
		if fd then
			fd:write("# TODO - " .. project .. "\n\n")
			fd:close()
			vim.notify("创建了新文件: " .. path)
		else
			return vim.notify("无法创建文件: " .. path, vim.log.levels.ERROR)
		end
	end

	if floating then
		show_todo_floating(path)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
	end
end

-- 📚 获取所有 TODO 项目
local function list_todo_projects()
	local todo_root = vim.fn.expand("~/.todo-files")
	local handle = vim.loop.fs_scandir(todo_root)
	if not handle then
		return {}, "没有找到 ~/.todo-files 目录。"
	end

	local choices, max_len = {}, 0
	while true do
		local name, typ = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		local path = todo_root .. "/" .. name .. "/todo.md"
		if typ == "directory" and vim.fn.filereadable(path) == 1 then
			table.insert(choices, { project = name, path = path })
			max_len = math.max(max_len, #name)
		end
	end

	if #choices == 0 then
		return {}, "没有可用的 todo 文件。"
	end
	return choices, nil, max_len
end

-- 📂 选择并打开 TODO 文件
function M.select_and_open_todo_file(floating)
	local choices, err, max_len = list_todo_projects()
	if err then
		return vim.notify(err, vim.log.levels.INFO)
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
			show_todo_floating(choice.path)
		else
			vim.cmd("edit " .. vim.fn.fnameescape(choice.path))
		end
	end)
end

-- 🗑️ 删除项目
function M.delete_project_todo()
	local choices, err, max_len = list_todo_projects()
	if err then
		return vim.notify(err, vim.log.levels.INFO)
	end

	vim.ui.select(choices, {
		prompt = "选择要删除的 TODO 项目：",
		format_item = function(item)
			local name_fmt = string.format("%-" .. max_len .. "s", item.project)
			return string.format("󰑉 %s    %s", name_fmt, vim.fn.fnamemodify(item.path, ":~"))
		end,
	}, function(choice)
		if not choice then
			return vim.notify("未选择任何项目文件夹", vim.log.levels.INFO)
		end

		if vim.fn.input("确定要删除: " .. choice.project .. " 吗？(y/n): "):lower() == "y" then
			local result =
				vim.fn.system("rm -rf " .. vim.fn.fnameescape(vim.fn.expand("~/.todo-files/" .. choice.project)))
			if vim.v.shell_error == 0 then
				vim.notify("成功删除项目: " .. choice.project)
			else
				vim.notify("删除失败: " .. result, vim.log.levels.ERROR)
			end
		else
			vim.notify("取消删除项目", vim.log.levels.INFO)
		end
	end)
end

-- 📝 转换为任务行
function M.convert_line_to_task()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	if line:match("^%s*%- %[[ xX%-~]%]") then
		return vim.notify("当前行已经是任务。", vim.log.levels.INFO)
	end
	local indent = line:match("^%s*") or ""
	local content = line:gsub("^[-*•+%d+%.%s]+", ""):match("^%s*(.-)%s*$")
	local new_line = indent .. "- [ ] " .. content
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { new_line })
	vim.api.nvim_win_set_cursor(0, { row, #new_line })
end

-- ➕ 插入新任务行
function M.new_task_item()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local indent = vim.fn.indent(row)
	local line = string.rep(" ", indent) .. "- [ ]  "
	vim.api.nvim_buf_set_lines(0, row, row, true, { line })
	vim.api.nvim_win_set_cursor(0, { row + 1, #line + 1 })
	vim.defer_fn(function()
		vim.cmd("startinsert")
	end, 10)
end

return M
