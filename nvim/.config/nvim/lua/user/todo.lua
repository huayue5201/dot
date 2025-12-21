local M = {}

-- ==========================
-- 虚拟文本命名空间
-- ==========================
local todo_ns = vim.api.nvim_create_namespace("todo_stats")

-- ==========================
-- 工具函数
-- ==========================
-- 静默通知，只在错误时显示
local function notify_silent(msg, level)
	if level == vim.log.levels.ERROR or level == vim.log.levels.WARN then
		local icons = {
			[vim.log.levels.WARN] = "⚠️ ",
			[vim.log.levels.ERROR] = "❌ ",
		}
		local icon = icons[level] or ""
		vim.notify(icon .. msg, level, { title = "TODO", timeout = 1500 })
	end
end

-- 获取行的缩进级别
local function get_indent_level(line)
	local indent = line:match("^(%s*)")
	return indent and #indent or 0
end

-- 判断是否是任务行
local function is_task_line(line)
	return line:match("^%s*[-*]%s+%[[ xX]%]")
end

-- 提取任务状态和内容
local function parse_task_line(line)
	local indent = get_indent_level(line)
	local task_match = line:match("^%s*[-*]%s+(%[[ xX]%])(.*)$")

	if not task_match then
		return nil
	end

	local status, content = task_match:match("(%[[ xX]%])(.*)$")
	return {
		indent = indent,
		status = status,
		content = content:gsub("^%s*(.-)%s*$", "%1"),
		is_done = status == "[x]" or status == "[X]",
		is_todo = status == "[ ]",
		line = line,
	}
end

-- ==========================
-- 任务分析相关函数
-- ==========================
local function analyze_task_tree(lines)
	local tasks = {}
	local stack = {}

	for i, line in ipairs(lines) do
		if is_task_line(line) then
			local task = parse_task_line(line)
			if task then
				task.line_num = i

				-- 找到父任务
				while #stack > 0 and stack[#stack].indent >= task.indent do
					table.remove(stack)
				end

				if #stack > 0 then
					task.parent = stack[#stack]
					if not task.parent.children then
						task.parent.children = {}
					end
					table.insert(task.parent.children, task)
				else
					task.parent = nil
				end

				table.insert(tasks, task)
				table.insert(stack, task)
			end
		end
	end

	return tasks
end

local function calculate_task_stats(task)
	local stats = { total = 0, done = 0 }

	if task.children and #task.children > 0 then
		for _, child in ipairs(task.children) do
			local child_stats = calculate_task_stats(child)
			stats.total = stats.total + child_stats.total
			stats.done = stats.done + child_stats.done
		end
	else
		stats.total = 1
		stats.done = task.is_done and 1 or 0
	end

	task.stats = stats
	return stats
end

-- ==========================
-- 高亮和虚拟文本管理（添加删除线）
-- ==========================
-- 更新单个任务的高亮和统计
local function update_task_display(bufnr, task)
	local line_num = task.line_num - 1
	local line = vim.fn.getline(task.line_num)
	local line_length = #line

	-- 清除该行现有的高亮和虚拟文本
	vim.api.nvim_buf_clear_namespace(bufnr, todo_ns, line_num, line_num + 1)

	-- 如果任务已完成，添加删除线和灰色高亮
	if task.is_done then
		-- 添加删除线高亮（覆盖整个行）
		vim.api.nvim_buf_set_extmark(bufnr, todo_ns, line_num, 0, {
			end_row = line_num,
			end_col = line_length,
			hl_group = "TodoStrikethrough",
			hl_mode = "combine",
			priority = 50,
		})

		-- 添加灰色高亮
		vim.api.nvim_buf_set_extmark(bufnr, todo_ns, line_num, 0, {
			end_row = line_num,
			end_col = line_length,
			hl_group = "TodoCompleted",
			hl_mode = "combine",
			priority = 49,
		})
	end

	-- 如果是父任务且有子任务，添加虚拟文本统计
	if task.children and #task.children > 0 then
		local stats = task.stats or { done = 0, total = 0 }
		vim.api.nvim_buf_set_extmark(bufnr, todo_ns, line_num, -1, {
			virt_text = { { string.format(" (%d/%d)", stats.done, stats.total), "Comment" } },
			virt_text_pos = "eol",
			hl_mode = "combine",
			right_gravity = false,
			priority = 100,
		})
	end
end

-- 更新任务及其所有子任务的高亮和统计
local function update_task_tree_display(bufnr, task)
	update_task_display(bufnr, task)

	-- 递归更新子任务
	if task.children then
		for _, child in ipairs(task.children) do
			update_task_tree_display(bufnr, child)
		end
	end
end

-- 更新所有任务的高亮和虚拟文本
local function update_all_virtual_text_and_highlights(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = analyze_task_tree(lines)

	-- 清除所有虚拟文本和高亮
	vim.api.nvim_buf_clear_namespace(bufnr, todo_ns, 0, -1)

	-- 计算所有任务的统计信息
	for _, task in ipairs(tasks) do
		if not task.parent then
			calculate_task_stats(task)
		end
	end

	-- 检查并更新父任务的状态（所有子任务完成时自动完成父任务）
	for _, task in ipairs(tasks) do
		if task.children and #task.children > 0 then
			local stats = task.stats
			local current_done = task.is_done
			local should_be_done = stats.done == stats.total

			-- 如果状态需要更新
			if should_be_done and not current_done then
				-- 所有子任务完成，但父任务未完成 → 自动完成父任务
				local line = vim.fn.getline(task.line_num)
				local new_line = line:gsub("%[ %]", "[x]")
				vim.fn.setline(task.line_num, new_line)
				task.is_done = true
			elseif not should_be_done and current_done then
				-- 有子任务未完成，但父任务已完成 → 取消完成父任务
				local line = vim.fn.getline(task.line_num)
				local new_line = line:gsub("%[[xX]%]", "[ ]")
				vim.fn.setline(task.line_num, new_line)
				task.is_done = false
			end
		end
	end

	-- 重新分析任务树（因为可能更新了父任务状态）
	tasks = analyze_task_tree(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

	-- 重新计算统计
	for _, task in ipairs(tasks) do
		if not task.parent then
			calculate_task_stats(task)
		end
	end

	-- 更新所有任务的显示
	for _, task in ipairs(tasks) do
		update_task_tree_display(bufnr, task)
	end
end

-- ==========================
-- Conceal 和高亮设置（添加删除线高亮组）
-- ==========================

local function setup_conceal_syntax(bufnr)
	vim.cmd([[
    syntax match markdownTodo /\[\s\]/ conceal cchar=☐
    syntax match markdownTodoDone /\[[xX]\]/ conceal cchar=☑
    highlight link markdownTodo Conceal
    highlight link markdownTodoDone Conceal
  ]])
end

local function apply_todo_conceal_to_buffer(bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		return -- 缓冲区没有在窗口中显示
	end

	-- 使用 API 设置窗口选项
	vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
	vim.api.nvim_set_option_value("concealcursor", "ncv", { win = win })

	setup_conceal_syntax(bufnr)
end

-- ==========================
-- 任务切换函数（支持父子任务同步）
-- ==========================
local function toggle_task_with_stats(bufnr, lnum)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = analyze_task_tree(lines)

	-- 找到当前行的任务
	local current_task = nil
	for _, task in ipairs(tasks) do
		if task.line_num == lnum then
			current_task = task
			break
		end
	end

	if not current_task then
		return false, "不是有效的任务项"
	end

	-- 切换任务状态
	local line = vim.fn.getline(lnum)
	local is_now_done = false

	if line:match("^%s*[-*]%s+%[ %]") then
		-- 未完成 -> 完成
		local new_line = line:gsub("%[ %]", "[x]")
		vim.fn.setline(lnum, new_line)
		current_task.is_done = true
		is_now_done = true

		-- 如果这是父任务，完成所有子任务
		if current_task.children and #current_task.children > 0 then
			for _, child in ipairs(current_task.children) do
				local child_line = vim.fn.getline(child.line_num)
				if child_line:match("^%s*[-*]%s+%[ %]") then
					local new_child_line = child_line:gsub("%[ %]", "[x]")
					vim.fn.setline(child.line_num, new_child_line)
					child.is_done = true
				end
			end
		end
	elseif line:match("^%s*[-*]%s+%[[xX]%]") then
		-- 完成 -> 未完成
		local new_line = line:gsub("%[[xX]%]", "[ ]")
		vim.fn.setline(lnum, new_line)
		current_task.is_done = false
		is_now_done = false

		-- 如果这是父任务，取消完成所有子任务
		if current_task.children and #current_task.children > 0 then
			for _, child in ipairs(current_task.children) do
				local child_line = vim.fn.getline(child.line_num)
				if child_line:match("^%s*[-*]%s+%[[xX]%]") then
					local new_child_line = child_line:gsub("%[[xX]%]", "[ ]")
					vim.fn.setline(child.line_num, new_child_line)
					child.is_done = false
				end
			end
		end
	else
		return false, "不是有效的任务项"
	end

	-- 更新虚拟文本和高亮
	update_all_virtual_text_and_highlights(bufnr)

	return true, is_now_done and "已完成" or "未完成"
end

-- ==========================
-- 批量任务切换
-- ==========================
function M.toggle_selected_tasks()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local changed_count = 0

	for lnum = start_line, end_line do
		local success, _ = toggle_task_with_stats(bufnr, lnum)
		if success then
			changed_count = changed_count + 1
		end
	end

	vim.cmd("normal! v")
end

function M.toggle_task()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")
	local success, status = toggle_task_with_stats(bufnr, lnum)

	if not success then
		notify_silent("不是有效的任务项", vim.log.levels.WARN)
	end
end

-- 通用插入任务函数
function M.insert_task(text, indent_extra)
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")

	-- 获取当前行缩进
	local current_line = vim.fn.getline(lnum)
	local indent = current_line:match("^(%s*)") or ""
	indent = indent .. string.rep(" ", indent_extra or 0)

	-- 插入任务行
	local new_task_line = indent .. "- [ ] " .. text
	vim.fn.append(lnum, new_task_line)

	-- 移动光标到新行
	local new_lnum = lnum + 1
	vim.fn.cursor(new_lnum, 1)

	-- 更新虚拟文本和高亮
	update_all_virtual_text_and_highlights(bufnr)

	-- 进入插入模式（在行尾）
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
end

-- ==========================
-- 统计和格式化函数
-- ==========================
local function summarize_tasks(lines)
	local tasks = analyze_task_tree(lines)
	local count = {
		todo = 0, -- 未完成的根任务数
		done = 0, -- 已完成的根任务数
		total_items = 0, -- 所有任务项数
		completed_items = 0, -- 已完成的任务项数
	}

	-- 遍历所有任务
	for _, task in ipairs(tasks) do
		if not task.parent then
			-- 根任务
			if task.is_done then
				count.done = count.done + 1
			else
				count.todo = count.todo + 1
			end
		end

		-- 所有任务项
		count.total_items = count.total_items + 1
		if task.is_done then
			count.completed_items = count.completed_items + 1
		end
	end

	count.total_tasks = count.todo + count.done
	return count
end

local function format_summary(stat)
	if stat.total_items == 0 then
		return "暂无任务"
	end

	local ratio = stat.completed_items / stat.total_items
	local filled = math.floor(ratio * 20)
	local bar = string.rep("▰", filled) .. string.rep("▱", 20 - filled)

	if stat.total_tasks == stat.total_items then
		-- 没有子任务
		return string.format(
			"%s %d%%｜完成: %d/%d",
			bar,
			math.floor(ratio * 100),
			stat.completed_items,
			stat.total_items
		)
	else
		-- 有子任务
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

-- ==========================
-- 文件管理函数
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

	local files = {}
	local f = vim.fn.globpath(dir, "*.todo.md", false, true)
	vim.list_extend(files, f)

	return files
end

-- ==========================
-- 按键映射设置
-- ==========================
local function setup_keymaps(bufnr)
	local keymaps = {
		{
			"n",
			"q",
			function()
				local win = vim.api.nvim_get_current_win()
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
			end,
			"关闭窗口",
		},
		{
			"n",
			"<C-r>",
			function()
				apply_todo_conceal_to_buffer(bufnr)
				update_all_virtual_text_and_highlights(bufnr)
				vim.cmd("redraw")
			end,
			"刷新显示",
		},
		{ "n", "<cr>", M.toggle_task, "切换任务状态" },
		{
			"i",
			"<C-CR>",
			function()
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
				M.toggle_task()
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
			end,
			"切换任务状态",
		},
		{ "v", "<cr>", M.toggle_selected_tasks, "批量切换任务状态" },
		{ "x", "<cr>", M.toggle_selected_tasks, "批量切换任务状态" },
		{
			"n",
			"<leader>nt",
			function()
				M.insert_task("新任务", 0)
			end,
			"新建任务",
		},
		{
			"n",
			"<leader>nT",
			function()
				M.insert_task("新任务", 2)
			end,
			"新建子任务",
		},
		{
			"n",
			"<leader>ns",
			function()
				M.insert_task("新任务", 0)
			end,
			"新建平级任务",
		},
	}

	for _, mapping in ipairs(keymaps) do
		vim.keymap.set(mapping[1], mapping[2], mapping[3], { buffer = bufnr, desc = mapping[4] })
	end
end

-- ==========================
-- Conceal 和高亮设置（添加删除线高亮组）
-- ==========================
local function setup_conceal()
	-- 添加删除线高亮组
	vim.cmd([[
    highlight TodoCompleted guifg=#888888 gui=italic
    highlight TodoStrikethrough gui=strikethrough cterm=strikethrough
  ]])

	vim.api.nvim_create_augroup("TodoConceal", { clear = true })

	-- 仅对 TODO 相关文件应用 conceal
	vim.api.nvim_create_autocmd({ "FileType" }, {
		group = "TodoConceal",
		pattern = { "markdown" },
		callback = function(args)
			local bufnr = args.buf
			local filename = vim.api.nvim_buf_get_name(bufnr)

			-- 只有 TODO 相关文件才应用 conceal
			if filename:match("%.todo%.md$") or filename:match("todo%.txt$") or filename:match("%.todo$") then
				apply_todo_conceal_to_buffer(bufnr)
				vim.defer_fn(function()
					update_all_virtual_text_and_highlights(bufnr)
				end, 100)
			end
		end,
	})

	-- 精确的文件名匹配
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		group = "TodoConceal",
		pattern = {
			"*.todo.md",
			"todo.txt",
			"*.todo",
		},
		callback = function(args)
			vim.bo[args.buf].filetype = "markdown"
			apply_todo_conceal_to_buffer(args.buf)
		end,
	})
end

-- ==========================
-- 浮窗管理
-- ==========================
local function show_todo_floating(path)
	-- 获取或创建缓冲区
	local buf = vim.fn.bufadd(path)
	vim.fn.bufload(buf)

	local buf_opts = {
		buftype = "",
		bufhidden = "wipe",
		modifiable = true,
		readonly = false,
		swapfile = false,
	}

	for opt, val in pairs(buf_opts) do
		vim.bo[buf][opt] = val
	end

	local ok, lines = pcall(vim.fn.readfile, path)
	if ok then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end

	local width = math.min(math.floor(vim.o.columns * 0.6), 140)
	local height = math.min(30, math.max(10, #lines + 4))
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = "rounded",
		title = "📋 TODO - " .. vim.fn.fnamemodify(path, ":t"),
		style = "minimal",
	})

	-- 应用 conceal 设置
	apply_todo_conceal_to_buffer(buf)

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

	setup_keymaps(buf)

	vim.defer_fn(function()
		update_all_virtual_text_and_highlights(buf)
		update_summary()
	end, 100)

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		buffer = buf,
		callback = function()
			update_summary()
			update_all_virtual_text_and_highlights(buf)
		end,
	})
end

-- ==========================
-- 公共 API 函数
-- ==========================
function M.open_todo_file(path, floating)
	if not vim.fn.filereadable(path) then
		notify_silent("文件不存在: " .. path, vim.log.levels.WARN)
		return
	end

	if floating then
		show_todo_floating(path)
	else
		vim.cmd("edit " .. vim.fn.fnameescape(path))
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

	local path = dir .. "/" .. filename .. ".todo.md"
	if vim.fn.filereadable(path) == 1 then
		notify_silent("文件已存在: " .. filename .. ".todo.md", vim.log.levels.WARN)
		return
	end

	local fd = io.open(path, "w")
	if fd then
		fd:write("# TODO - " .. filename .. "\n\n")
		fd:close()
	else
		notify_silent("无法创建文件: " .. path, vim.log.levels.ERROR)
	end
end

function M.delete_todo_file(path)
	if not vim.fn.filereadable(path) then
		notify_silent("文件不存在: " .. path, vim.log.levels.WARN)
		return
	end

	local confirm = vim.fn.input("🗑️ 确定删除 " .. vim.fn.fnamemodify(path, ":t") .. " 吗? (y/n): "):lower()
	if confirm == "y" then
		os.remove(path)
	end
end

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
				local name = vim.loop.fs_scandir_next(handle)
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
		return
	end

	vim.ui.select(choices, {
		prompt = "🗂️ 选择 TODO 文件：",
		format_item = function(item)
			return string.format("%-20s • %s", item.project, vim.fn.fnamemodify(item.path, ":t"))
		end,
	}, callback)
end

-- ==========================
-- 初始化
-- ==========================
setup_conceal()

return M
