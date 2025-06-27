local uv = vim.loop
local api = vim.api

local M = {}

-- ======= 内部函数 =======

-- 统一管理缓存
local cached_tasks = {}

-- 加载任务模块（带缓存）
local function load_tasks_from_dir(dir)
	if cached_tasks[dir] then
		return cached_tasks[dir]
	end

	local task_list = {}
	local task_path = vim.fn.stdpath("config") .. "/lua/" .. dir
	local handle = uv.fs_scandir(task_path)

	if not handle then
		vim.notify("任务目录未找到: " .. task_path, vim.log.levels.ERROR)
		return {}
	end

	while true do
		local name, t = uv.fs_scandir_next(handle)
		if not name then
			break
		end

		if t == "file" and name:match("%.lua$") then
			local mod_name = dir:gsub("/", ".") .. "." .. name:gsub("%.lua$", "")
			local ok, task = pcall(require, mod_name)

			if ok and type(task) == "table" then
				table.insert(task_list, task)
			else
				vim.notify("加载任务失败: " .. mod_name, vim.log.levels.ERROR)
			end
		end
	end

	cached_tasks[dir] = task_list
	return task_list
end

-- 项目类型配置表
local project_types = {
	make = { "Makefile" },
	cargo = { "Cargo.toml" },
	python = { "setup.py", "requirements.txt" },
	node = { "package.json" },
}

-- 检测项目类型
local function detect_project_type()
	for project_type, files in pairs(project_types) do
		for _, file in ipairs(files) do
			if uv.fs_stat(file) then
				return project_type
			end
		end
	end
	return "unknown"
end

-- 设置 errorformat
local function setup_errorformat(project_type)
	local formats = {
		make = " %f:%l:%c: %t%*[^:]: %m,%E%f:%l:%c: %t%*[^:]: %m,%C%.%#,%Z",
		cargo = " %f:%l:%c: %m,%Eerror: %m,%C%.%#,%Z",
	}

	vim.opt_local.errorformat = formats[project_type] or "%f:%l:%c: %m"
end

-- 添加内容到 QuickFix
local function append_to_qf(data)
	if not data or #data == 0 then
		return
	end

	local lines = vim.tbl_filter(function(line)
		return line ~= ""
	end, data)

	if #lines == 0 then
		return
	end

	local qf_exists = false
	for _, win in ipairs(api.nvim_list_wins()) do
		local buf = api.nvim_win_get_buf(win)
		if api.nvim_buf_get_option(buf, "buftype") == "quickfix" then
			vim.fn.setqflist({}, "a", { lines = lines })
			api.nvim_win_set_cursor(win, { api.nvim_buf_line_count(buf), 0 })
			qf_exists = true
			break
		end
	end

	if not qf_exists then
		vim.fn.setqflist({}, "a", { lines = lines })
		vim.cmd("copen")
	end
end

-- ======= 对外暴露 =======

M.tasks = load_tasks_from_dir("tasks")

function M.clear_task_cache()
	cached_tasks = {}
end

-- 运行任务并处理输出
function M.run_job(cmd, opts)
	opts = opts or {}

	local function handle_output(_, data)
		if data and type(data) == "table" then
			append_to_qf(data)
			if opts.handler then
				opts.handler(data)
			end
		end
	end

	local job_opts = {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = handle_output,
		on_stderr = handle_output,
		on_exit = opts.on_exit,
	}

	return vim.fn.jobstart(cmd, job_opts)
end

-- 执行任务
function M.run_task(task)
	if not task or type(task.run) ~= "function" then
		vim.notify("无效的任务", vim.log.levels.ERROR)
		return
	end

	vim.fn.setqflist({}, " ", { title = "任务输出", lines = { "任务开始执行..." } })
	vim.cmd("copen")

	local job_id = task.run()
	if not job_id or job_id == 0 then
		vim.notify("启动任务失败", vim.log.levels.ERROR)
	end
end

-- 构建任务
function M.build()
	local project_type = detect_project_type()

	setup_errorformat(project_type)

	local available_tasks = {}
	for _, task in ipairs(M.tasks) do
		if task.project_type == project_type or task.project_type == "any" then
			table.insert(available_tasks, task)
		end
	end

	if #available_tasks == 0 then
		vim.notify("没有可用构建任务", vim.log.levels.WARN)
		return
	end

	vim.ui.select(available_tasks, {
		prompt = " 任务列表   ",
		format_item = function(item)
			return item.label
		end,
	}, function(choice)
		if choice then
			M.run_task(choice)
		end
	end)
end

return M
