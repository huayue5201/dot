local M = {}

-- ==========================
-- 通知美化
-- ==========================
local function notify(msg, level, opts)
	local icons = {
		[vim.log.levels.INFO] = "ℹ️ ",
		[vim.log.levels.WARN] = "⚠️ ",
		[vim.log.levels.ERROR] = "❌ ",
		[vim.log.levels.DEBUG] = "🐛 ",
		[vim.log.levels.TRACE] = "🔍 ",
	}
	local icon = icons[level] or "✅ "
	vim.notify(
		icon .. msg,
		level,
		vim.tbl_extend("force", {
			title = "TODO 管理器",
			timeout = 2000,
		}, opts or {})
	)
end

-- ==========================
-- 状态标签定义
-- ==========================
local STATE_LABELS = {
	todo = { symbols = { "[ ]", "☐", "□" }, display = "未完成" },
	done = { symbols = { "[x]", "✔", "☑", "✅" }, display = "完成" },
}

local function escape_lua_pattern(s)
	return s:gsub("([^%w])", "%%%1")
end

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

local function render_progress_bar(done, total, bar_length)
	if total == 0 then
		return "暂无任务"
	end
	local ratio = done / total
	local filled = math.floor(ratio * bar_length)
	local bar = string.rep("▰", filled) .. string.rep("▱", bar_length - filled)
	return string.format("%s %d%% (%d/%d)", bar, math.floor(ratio * 100), done, total)
end

local function format_summary(stat)
	if stat.total == 0 then
		return "暂无任务"
	end
	local bar = render_progress_bar(stat.done, stat.total, 20)
	return string.format("%s｜未完成: %d｜完成: %d｜总计: %d", bar, stat.todo, stat.done, stat.total)
end

-- ==========================
-- 项目和路径管理
-- ==========================
local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_project_dir(project)
	return vim.fn.expand("~/.todo-files/" .. project)
end

local function get_todo_files(project)
	local dir = get_project_dir(project)
	if vim.fn.isdirectory(dir) == 0 then
		return {}
	end
	return vim.fn.globpath(dir, "*.todo.md", false, true)
end

-- ==========================
-- 浮窗组件
-- ==========================
local function show_todo_floating(path)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, path)
	vim.bo[buf].buftype = ""
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = true
	vim.bo[buf].readonly = false
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"

	local ok, lines = pcall(vim.fn.readfile, path)
	if ok then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	local width = math.min(math.floor(vim.o.columns * 0.6), 140)
	local height = math.min(30, math.max(10, #lines + 4))

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		title = "📋 TODO - " .. vim.fn.fnamemodify(path, ":t"),
		style = "minimal",
	})

	local function update_summary()
		local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local stat = summarize_tasks(current_lines)
		local footer_text = format_summary(stat)
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_set_config(win, {
				footer = { { " " .. footer_text .. " ", "Number" } },
				footer_pos = "right",
			})
		end
	end

	-- 关闭浮窗
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
			notify("已关闭窗口", vim.log.levels.INFO)
		end
	end, { buffer = buf, desc = "关闭窗口" })

	-- 保存文件
	vim.keymap.set("n", "<C-s>", function()
		vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), path)
		update_summary()
		notify("文件已保存 ✅", vim.log.levels.INFO)
	end, { buffer = buf, desc = "保存" })

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		buffer = buf,
		callback = update_summary,
	})

	update_summary()
end

-- ==========================
-- 打开 TODO 文件
-- ==========================
function M.open_todo_file(path, floating)
	if not vim.fn.filereadable(path) then
		return notify("文件不存在: " .. path, vim.log.levels.WARN)
	end
	if floating then
		show_todo_floating(path)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		notify("已打开文件：" .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
	end
end

-- ==========================
-- 创建 TODO 文件
-- ==========================
function M.create_todo_file()
	local project = get_project()
	local dir = get_project_dir(project)
	vim.fn.mkdir(dir, "p")

	local filename = vim.fn.input("📝 请输入 TODO 文件名: ")
	if filename == "" then
		return notify("取消创建 TODO 文件", vim.log.levels.INFO)
	end

	local path = dir .. "/" .. filename .. ".md"
	if vim.fn.filereadable(path) == 1 then
		return notify("文件已存在: " .. filename .. ".md", vim.log.levels.WARN)
	end

	local fd = io.open(path, "w")
	if fd then
		fd:write("# TODO - " .. filename .. "\n\n")
		fd:close()
		notify("创建成功：" .. path, vim.log.levels.INFO)
	else
		notify("无法创建文件: " .. path, vim.log.levels.ERROR)
	end
end

-- ==========================
-- 删除 TODO 文件
-- ==========================
function M.delete_todo_file(path)
	if not vim.fn.filereadable(path) then
		return notify("文件不存在: " .. path, vim.log.levels.WARN)
	end
	if vim.fn.input("🗑️ 确定删除 " .. vim.fn.fnamemodify(path, ":t") .. " 吗? (y/n): "):lower() == "y" then
		os.remove(path)
		notify("已删除: " .. path, vim.log.levels.WARN)
	else
		notify("已取消删除", vim.log.levels.INFO)
	end
end

-- ==========================
-- 选择 TODO 文件
-- ==========================
function M.select_todo_file(scope, callback)
	local choices = {}
	if scope == "current" then
		local project = get_project()
		local files = get_todo_files(project)
		for _, f in ipairs(files) do
			table.insert(choices, { project = project, path = f })
		end
	elseif scope == "all" then
		local root = vim.fn.expand("~/.todo-files")
		local handle = vim.loop.fs_scandir(root)
		if handle then
			while true do
				local name, typ = vim.loop.fs_scandir_next(handle)
				if not name then
					break
				end
				local files = get_todo_files(name)
				for _, f in ipairs(files) do
					table.insert(choices, { project = name, path = f })
				end
			end
		end
	end

	if #choices == 0 then
		return notify("没有可用的 TODO 文件", vim.log.levels.INFO)
	end

	vim.ui.select(choices, {
		prompt = "🗂️ 选择 TODO 文件：",
		format_item = function(item)
			return string.format("%-20s • %s", item.project, vim.fn.fnamemodify(item.path, ":t"))
		end,
	}, callback)
end

return M
