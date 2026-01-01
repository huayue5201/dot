local core = require("todo.core")
local render = require("todo.render")

local M = {}

---------------------------------------------------------------------
-- 常量定义
---------------------------------------------------------------------
local KEYMAPS = {
	close = { "n", "q", "关闭窗口" },
	refresh = { "n", "<C-r>", "刷新显示" },
	toggle = { "n", "<cr>", "切换任务状态" },
	toggle_insert = { "i", "<C-CR>", "切换任务状态" },
	toggle_selected = { { "v", "x" }, "<cr>", "批量切换任务状态" }, -- 合并模式
	new_task = { "n", "<leader>nt", "新建任务" },
	new_subtask = { "n", "<leader>nT", "新建子任务" },
	new_sibling = { "n", "<leader>ns", "新建平级任务" },
}

---------------------------------------------------------------------
-- Conceal 设置
---------------------------------------------------------------------

local function setup_conceal_syntax(bufnr)
	vim.cmd(string.format(
		[[
        buffer %d
        syntax match markdownTodo /\[\s\]/ conceal cchar=☐
        syntax match markdownTodoDone /\[[xX]\]/ conceal cchar=☑
        highlight default link markdownTodo Conceal
        highlight default link markdownTodoDone Conceal
    ]],
		bufnr
	))
end

local function apply_conceal(bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		return
	end

	vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
	vim.api.nvim_set_option_value("concealcursor", "ncv", { win = win })

	setup_conceal_syntax(bufnr)
end

---------------------------------------------------------------------
-- 批量切换任务状态（统一处理可视模式）
---------------------------------------------------------------------
local function toggle_selected_tasks(bufnr, win)
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local changed_count = 0

	for lnum = start_line, end_line do
		local success, _ = core.toggle_line(bufnr, lnum)
		if success then
			changed_count = changed_count + 1
		end
	end

	-- 退出可视模式
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)

	return changed_count
end

---------------------------------------------------------------------
-- 文件管理（添加缓存）
---------------------------------------------------------------------
local _file_cache = {}

local function get_project()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function get_project_dir(project)
	return vim.fn.expand("~/.todo-files/" .. project)
end

local function get_todo_files(project, force_refresh)
	if not force_refresh and _file_cache[project] then
		return _file_cache[project]
	end

	local dir = get_project_dir(project)
	if vim.fn.isdirectory(dir) == 0 then
		_file_cache[project] = {}
		return {}
	end

	local files = vim.fn.globpath(dir, "*.todo.md", false, true)
	_file_cache[project] = files
	return files
end

---------------------------------------------------------------------
-- 选择 TODO 文件
---------------------------------------------------------------------
function M.select_todo_file(scope, callback)
	local choices = {}
	local projects = {}

	if scope == "current" then
		local project = get_project()
		projects = { project }
	elseif scope == "all" then
		local root = vim.fn.expand("~/.todo-files")
		local handle = vim.loop.fs_scandir(root)
		if handle then
			while true do
				local name = vim.loop.fs_scandir_next(handle)
				if not name then
					break
				end
				table.insert(projects, name)
			end
		end
	end

	for _, project in ipairs(projects) do
		for _, f in ipairs(get_todo_files(project)) do
			table.insert(choices, { project = project, path = f })
		end
	end

	if #choices == 0 then
		vim.notify("未找到 TODO 文件", vim.log.levels.WARN)
		return
	end

	vim.ui.select(choices, {
		prompt = "🗂️ 选择 TODO 文件：",
		format_item = function(item)
			return string.format("%-20s • %s", item.project, vim.fn.fnamemodify(item.path, ":t"))
		end,
	}, callback)
end

---------------------------------------------------------------------
-- 统计 footer
---------------------------------------------------------------------
local function format_summary(stat)
	if stat.total_items == 0 then
		return "暂无任务"
	end

	local ratio = stat.completed_items / stat.total_items
	local filled = math.floor(ratio * 20)
	local bar = string.rep("▰", filled) .. string.rep("▱", 20 - filled)

	if stat.total_tasks == stat.total_items then
		return string.format(
			"%s %d%%｜完成: %d/%d",
			bar,
			math.floor(ratio * 100),
			stat.completed_items,
			stat.total_items
		)
	else
		return string.format(
			"%s %d%%｜主任务: %d/%d｜总计: %d/%d",
			bar,
			math.floor(ratio * 100),
			stat.done,
			stat.total_tasks,
			stat.completed_items,
			stat.total_items
		)
	end
end

---------------------------------------------------------------------
-- 刷新渲染
---------------------------------------------------------------------
function M.refresh(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local tasks = core.parse_tasks(lines)
	core.calculate_all_stats(tasks)
	core.sync_parent_child_state(tasks, bufnr)
	core.calculate_all_stats(tasks)

	local roots = core.get_root_tasks(tasks)
	render.render_all(bufnr, roots)

	return tasks
end

---------------------------------------------------------------------
-- 插入任务函数
---------------------------------------------------------------------
function M.insert_task(text, indent_extra, bufnr)
	local target_buf = bufnr or vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")

	-- 获取当前行缩进
	local current_line = vim.api.nvim_buf_get_lines(target_buf, lnum - 1, lnum, false)[1] or ""
	local indent = current_line:match("^(%s*)") or ""
	indent = indent .. string.rep(" ", indent_extra or 0)

	-- 插入任务行
	local new_task_line = indent .. "- [ ] " .. (text or "新任务")
	vim.api.nvim_buf_set_lines(target_buf, lnum, lnum, false, { new_task_line })

	-- 移动光标到新行
	local new_lnum = lnum + 1
	vim.fn.cursor(new_lnum, 1)

	-- 更新虚拟文本和高亮
	M.refresh(target_buf)

	-- 进入插入模式（在行尾）
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
end

---------------------------------------------------------------------
-- 统一键映射设置
---------------------------------------------------------------------
local function setup_keymaps(bufnr, win)
	local keymap_handlers = {
		close = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end,
		refresh = function()
			apply_conceal(bufnr)
			M.refresh(bufnr)
			vim.cmd("redraw")
		end,
		toggle = function()
			local lnum = vim.fn.line(".")
			core.toggle_line(bufnr, lnum)
			M.refresh(bufnr)
		end,
		toggle_insert = function()
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
			local lnum = vim.fn.line(".")
			core.toggle_line(bufnr, lnum)
			M.refresh(bufnr)
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
		end,
		toggle_selected = function()
			local changed = toggle_selected_tasks(bufnr, win)
			M.refresh(bufnr)
		end,
		new_task = function()
			M.insert_task("新任务", 0, bufnr)
		end,
		new_subtask = function()
			M.insert_task("新任务", 2, bufnr)
		end,
		new_sibling = function()
			M.insert_task("新任务", 0, bufnr)
		end,
	}

	for key, mapping in pairs(KEYMAPS) do
		local modes = type(mapping[1]) == "table" and mapping[1] or { mapping[1] }
		local keybind = mapping[2]
		local desc = mapping[3]
		local handler = keymap_handlers[key]

		if handler then
			for _, mode in ipairs(modes) do
				vim.keymap.set(mode, keybind, handler, { buffer = bufnr, desc = desc })
			end
		end
	end
end

---------------------------------------------------------------------
-- 浮窗 UI
---------------------------------------------------------------------
local function create_floating_window(bufnr, path, line_number)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		vim.notify("无法读取文件: " .. path, vim.log.levels.ERROR)
		return
	end

	local width = math.min(math.floor(vim.o.columns * 0.6), 140)
	local height = math.min(30, math.max(10, #lines + 4))
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = "rounded",
		title = "📋 TODO - " .. vim.fn.fnamemodify(path, ":t"),
		style = "minimal",
	})

	apply_conceal(bufnr)

	-- 更新统计信息的函数
	local function update_summary()
		if not vim.api.nvim_win_is_valid(win) then
			return
		end

		local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local stat = core.summarize(current_lines)
		local footer_text = format_summary(stat)

		pcall(vim.api.nvim_win_set_config, win, {
			footer = { { " " .. footer_text .. " ", "Number" } },
			footer_pos = "right",
		})
	end

	setup_keymaps(bufnr, win)

	return win, update_summary
end

local function show_floating(path, line_number, enter_insert)
	local bufnr = vim.fn.bufadd(path)
	vim.fn.bufload(bufnr)

	-- 设置缓冲区选项
	local buf_opts = {
		buftype = "",
		bufhidden = "wipe",
		modifiable = true,
		readonly = false,
		swapfile = false,
		filetype = "markdown",
	}

	for opt, val in pairs(buf_opts) do
		vim.bo[bufnr][opt] = val
	end

	local win, update_summary = create_floating_window(bufnr, path, line_number)
	if not win then
		return
	end

	vim.defer_fn(function()
		M.refresh(bufnr)
		update_summary()

		if line_number then
			vim.api.nvim_win_set_cursor(win, { line_number, 0 })
			vim.api.nvim_win_call(win, function()
				vim.cmd("normal! zz")
			end)
			-- 进入行尾插入模式
			if enter_insert then
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
			end
		end
	end, 50)

	local augroup = vim.api.nvim_create_augroup("TodoFloating_" .. path:gsub("[^%w]", "_"), { clear = true })

	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(win),
		once = true,
		callback = function()
			vim.api.nvim_del_augroup_by_id(augroup)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = augroup,
		buffer = bufnr,
		callback = function()
			if vim.api.nvim_win_is_valid(win) then
				M.refresh(bufnr)
				update_summary()
			end
		end,
	})

	return bufnr, win
end

---------------------------------------------------------------------
-- 公开 API
---------------------------------------------------------------------
function M.open_todo_file(path, floating, line_number, opts)
	opts = opts or {}
	local enter_insert = opts.enter_insert ~= false -- ⭐ 默认 true，传 false 则关闭

	-- 确保是绝对路径
	path = vim.fn.fnamemodify(path, ":p")

	if not vim.fn.filereadable(path) then
		vim.notify("文件不存在: " .. path, vim.log.levels.ERROR)
		return
	end

	if floating then
		return show_floating(path, line_number, enter_insert)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		local bufnr = vim.api.nvim_get_current_buf()
		if line_number then
			vim.fn.cursor(line_number, 1)
		end
		apply_conceal(bufnr)
		M.refresh(bufnr)
		return bufnr
	end
end

function M.create_todo_file()
	local project = get_project()
	local dir = get_project_dir(project)
	vim.fn.mkdir(dir, "p")

	local filename = vim.fn.input("📝 请输入 TODO 文件名: ")
	if filename == "" then
		return
	end

	if not filename:match("%.todo%.md$") then
		filename = filename .. ".todo.md"
	end

	local path = dir .. "/" .. filename
	if vim.fn.filereadable(path) == 1 then
		vim.notify("文件已存在: " .. filename, vim.log.levels.WARN)
		return
	end

	local fd = io.open(path, "w")
	if fd then
		fd:write("# TODO - " .. filename:gsub("%.todo%.md$", "") .. "\n\n")
		fd:close()
		vim.notify("创建成功: " .. path, vim.log.levels.INFO)
		return path
	else
		vim.notify("无法创建文件: " .. path, vim.log.levels.ERROR)
		return nil
	end
end

function M.delete_todo_file(path)
	if not vim.fn.filereadable(path) then
		vim.notify("文件不存在: " .. path, vim.log.levels.ERROR)
		return false
	end

	local confirm = vim.fn.input("🗑️ 确定删除 " .. vim.fn.fnamemodify(path, ":t") .. " 吗? (y/n): "):lower()
	if confirm == "y" then
		local success = os.remove(path)
		if success then
			vim.notify("删除成功", vim.log.levels.INFO)
			-- 清除缓存
			_file_cache = {}
			return true
		else
			vim.notify("删除失败", vim.log.levels.ERROR)
			return false
		end
	end
	return false
end

function M.toggle_selected_tasks()
	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.fn.bufwinid(bufnr)

	if win == -1 then
		vim.notify("未在窗口中找到缓冲区", vim.log.levels.ERROR)
		return 0
	end

	local changed = toggle_selected_tasks(bufnr, win)
	M.refresh(bufnr)
	return changed
end

-- 添加缓存清理函数
function M.clear_cache()
	_file_cache = {}
	vim.notify("已清除文件缓存", vim.log.levels.INFO)
end

return M
