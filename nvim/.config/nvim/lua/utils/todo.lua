local M = {}

-- ✅ 状态标签定义
local STATE_LABELS = {
	todo = { symbols = { "[ ]", "☐", "□" }, display = "未完成" },
	done = { symbols = { "[x]", "✔", "☑", "✅" }, display = "完成" },
}

-- ✅ 转义 Lua 模式字符
local function escape_lua_pattern(s)
	return s:gsub("([^%w])", "%%%1")
end

-- ✅ 统计任务状态
local function summarize_tasks(lines)
	local count = { todo = 0, done = 0 }
	for _, line in ipairs(lines) do
		for label, info in pairs(STATE_LABELS) do
			for _, symbol in ipairs(info.symbols) do
				if line:match(escape_lua_pattern(symbol)) then
					count[label] = count[label] + 1
					break
				end
			end
		end
	end
	count.total = count.todo + count.done
	return count
end

-- ✅ 绘制进度条
local function render_progress_bar(done, total, bar_length)
	if total == 0 then
		return "暂无任务"
	end
	local ratio = done / total
	local filled = math.floor(ratio * bar_length)
	-- local bar = string.rep("█", filled) .. string.rep("░", bar_length - filled)
	local bar = string.rep("▣", filled) .. string.rep("□", bar_length - filled)
	return string.format("%s %d%% (%d/%d)", bar, math.floor(ratio * 100), done, total)
end

-- ✅ 构造状态摘要（含进度条）
local function format_summary(stat)
	if stat.total == 0 then
		return "暂无任务"
	end
	local bar = render_progress_bar(stat.done, stat.total, 20)
	return string.format("%s｜未完成: %d｜完成: %d｜总计: %d", bar, stat.todo, stat.done, stat.total)
end

-- 📁 获取项目路径
local function get_project_path(project)
	return vim.fn.expand("~/.todo-files/" .. project .. "/todo.md")
end

-- 📁 获取当前项目名
local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 🪟 显示浮动窗口
local function show_todo_floating(path)
	local abs_path = vim.fn.fnamemodify(path, ":p")

	local buf = vim.fn.bufadd(abs_path)
	vim.fn.bufload(buf)
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buftype = ""
	vim.bo[buf].modifiable = true

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local stat = summarize_tasks(lines)

	local width = math.min(math.floor(vim.o.columns * 0.8), 160)
	local height = math.min(30, math.max(10, #lines + 4))

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		title = "󱑆 TODO清单 - " .. get_project(),
		footer = { { " " .. format_summary(stat) .. " ", "Number" } },
		footer_pos = "right",
	})

	-- 动态更新底部进度条
	local function update_summary()
		local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local new_summary = format_summary(summarize_tasks(current_lines))
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_set_config(win, {
				footer = { { " " .. new_summary .. " ", "Number" } },
				footer_pos = "right",
			})
		end
	end

	-- 快捷键：关闭与保存
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, desc = "关闭窗口" })

	vim.keymap.set("n", "<C-s>", function()
		vim.cmd("write")
		update_summary()
		vim.notify("✅ TODO 文件已保存并更新统计", vim.log.levels.INFO)
	end, { buffer = buf, desc = "保存并更新统计" })

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		buffer = buf,
		callback = update_summary,
	})
end

-- 📂 获取所有 TODO 项目
local function list_todo_projects()
	local todo_root = vim.fn.expand("~/.todo-files")
	local handle = vim.loop.fs_scandir(todo_root)
	if not handle then
		return {}, "没有找到 ~/.todo-files 目录。"
	end

	local choices = {}
	while true do
		local name, typ = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		local path = get_project_path(name)
		if typ == "directory" and vim.fn.filereadable(path) == 1 then
			table.insert(choices, { project = name, path = path })
		end
	end

	if #choices == 0 then
		return {}, "没有可用的 todo 文件。"
	end
	return choices
end

-- 📂 通用项目选择器
local function select_project(prompt, action)
	local choices, err = list_todo_projects()
	if err then
		return vim.notify(err, vim.log.levels.INFO)
	end

	local max_len = 0
	for _, item in ipairs(choices) do
		max_len = math.max(max_len, #item.project)
	end

	vim.ui.select(choices, {
		prompt = prompt,
		format_item = function(item)
			local name_fmt = string.format("%-" .. max_len .. "s", item.project)
			return string.format("󰑉 %s    %s", name_fmt, vim.fn.fnamemodify(item.path, ":~"))
		end,
	}, action)
end

-- 📄 打开或创建 TODO 文件
function M.open_or_create_todo_file(floating)
	local project = get_project()
	local path = get_project_path(project)

	if vim.fn.filereadable(path) == 0 then
		if vim.fn.input(" 当前项目没有  todo 文件，是否创建？(y/n): "):lower() ~= "y" then
			return vim.notify("取消创建 todo 文件。", vim.log.levels.INFO)
		end

		vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
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

-- 📂 选择并打开 TODO 文件
function M.select_and_open_todo_file(floating)
	select_project("选择要打开的 TODO 文件：", function(choice)
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
	select_project("选择要删除的 TODO 项目：", function(choice)
		if not choice then
			return vim.notify("未选择任何项目文件夹", vim.log.levels.INFO)
		end
		if vim.fn.input("确定要删除: " .. choice.project .. " 吗？(y/n): "):lower() == "y" then
			local dir_path = vim.fn.fnamemodify(choice.path, ":h")
			local result = vim.fn.system("rm -rf " .. vim.fn.fnameescape(dir_path))
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
