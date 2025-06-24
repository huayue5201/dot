-- NOTE:https://github.com/bngarren/checkmate.nvim  备选插件

local M = {}

-- 常量定义
local CHECKBOX_PATTERNS = { "[ ]", "[x]" } -- 只关注已完成和未完成的任务
local STATE_LABELS = {
	todo = { symbol = "[ ]", display = "未完成" }, -- 未完成
	done = { symbol = "[x]", display = "完成" }, -- 已完成
}

-- ✅ 统计任务状态，基于复选框过滤空行
local function summarize_tasks(lines)
	-- 初始化计数器
	local count = { todo = 0, done = 0 }

	-- 遍历每一行
	for _, line in ipairs(lines) do
		-- 只统计包含复选框的行
		for label, info in pairs(STATE_LABELS) do
			-- 如果当前行包含任务复选框符号
			if line:match("%" .. info.symbol) then
				-- 增加对应的任务状态计数
				count[label] = count[label] + 1
			end
		end
	end

	-- 计算总计
	count.total = count.todo + count.done

	return count
end

-- ✅ 构造状态摘要
local function format_summary(stat)
	-- 格式化任务状态统计摘要
	return string.format("未完成: %d  完成: %d  总计: %d", stat.todo, stat.done, stat.total)
end

-- 📁 获取当前项目名
local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 🪟 显示浮动窗口，只显示统计信息
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

	-- 打开浮动窗口并显示统计信息
	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		title = " 󱑆 TODO清单 ",
		style = "minimal",
		footer = { { " " .. summary .. " ", "Number" } }, -- 显示统计信息
		footer_pos = "right",
	})

	-- 编辑文件内容，第一行不显示统计信息
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

return M
