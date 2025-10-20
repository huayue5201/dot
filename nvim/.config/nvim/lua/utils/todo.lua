local M = {}

-- ✅ 状态标签定义（支持多种符号）
local STATE_LABELS = {
	todo = { symbols = { "[ ]", "☐", "□" }, display = "未完成" },
	done = { symbols = { "[x]", "✔", "☑", "✅" }, display = "完成" },
}

-- ✅ 读取文件内容
local function read_file_lines(path)
	local lines = {}
	local fd = io.open(path, "r")
	if fd then
		for line in fd:lines() do
			table.insert(lines, line)
		end
		fd:close()
	end
	return lines
end

-- ✅ 转义 Lua 模式字符
local function escape_lua_pattern(s)
	return s:gsub("([^%w])", "%%%1")
end

-- ✅ 统计任务状态（支持多种符号）
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
local function render_progress_bar(done, total, width)
	if total == 0 then
		return "暂无任务"
	end
	local ratio = done / total
	local filled = math.floor(ratio * width)
	local bar = string.rep("█", filled) .. string.rep("░", width - filled)
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

-- 📁 获取当前项目名
local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 📁 获取项目路径
local function get_project_path(project)
	return vim.fn.expand("~/.todo-files/" .. project .. "/todo.md")
end

-- 🪟 显示浮动窗口
local function show_todo_floating(path)
	local abs_path = vim.fn.fnamemodify(path, ":p")

	local buf = vim.fn.bufnr(abs_path)
	if buf == -1 or buf == 0 then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, abs_path)
		local lines = read_file_lines(abs_path)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].buftype = ""
	vim.bo[buf].modifiable = true

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local stat = summarize_tasks(lines)

	local width = math.min(100, math.max(60, math.floor(vim.o.columns * 0.6)))
	local height = math.min(30, math.max(10, #lines + 4))

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		title = "󱑆 TODO清单 - " .. get_project(),
		style = "minimal",
		footer = { { " " .. format_summary(stat) .. " ", "Number" } },
		footer_pos = "right",
	})

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

	-- 快捷键
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf })

	vim.keymap.set("n", "<C-s>", function()
		vim.cmd("write")
		update_summary()
		vim.notify("✅ TODO 文件已保存并更新统计", vim.log.levels.INFO)
	end, { buffer = buf, desc = "保存TODO文件" })

	-- 自动更新统计
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		buffer = buf,
		callback = update_summary,
	})

	return win
end

-- 📄 打开或创建 TODO 文件
function M.open_or_create_todo_file(floating)
	local project = get_project()
	local path = get_project_path(project)

	if vim.fn.filereadable(path) == 0 then
		if vim.fn.input("当前项目没有 TODO 文件，是否创建？(y/n): "):lower() ~= "y" then
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

return M
