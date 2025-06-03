-- lua/utils/neotask.lua

local uv = vim.loop
local api = vim.api

local M = {}

-- ======= 内部函数 =======

-- 加载任务模块
local function load_tasks_from_dir(dir)
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
			local ok, task = pcall(require, dir:gsub("/", ".") .. "." .. name:gsub("%.lua$", ""))
			if ok and type(task) == "table" then
				table.insert(task_list, task)
			else
				vim.notify("加载任务失败: " .. name, vim.log.levels.ERROR)
			end
		end
	end

	return task_list
end

-- 检测项目类型
local function detect_project_type()
	if uv.fs_stat("Makefile") then
		return "make"
	elseif uv.fs_stat("Cargo.toml") then
		return "cargo"
	end
	return nil
end

-- 设置 errorformat
local function setup_errorformat(project_type)
	if project_type == "make" then
		vim.opt_local.errorformat = {
			"%f:%l:%c: %t%*[^:]: %m",
			"%E%f:%l:%c: %t%*[^:]: %m",
			"%C%.%#",
			"%Z",
		}
	elseif project_type == "cargo" then
		vim.opt_local.errorformat = {
			"%f:%l:%c: %m",
			"%Eerror: %m",
			"%C%.%#",
			"%Z",
		}
	else
		vim.opt_local.errorformat = "%f:%l:%c: %m"
	end
end

-- 追加输出到 quickfix
local function append_to_qf(data)
	local lines = vim.tbl_filter(function(line)
		return line ~= ""
	end, data)
	if #lines > 0 then
		vim.fn.setqflist({}, "a", { lines = lines })
		for _, win in ipairs(api.nvim_list_wins()) do
			local buf = api.nvim_win_get_buf(win)
			if api.nvim_get_option_value("buftype", { buf = buf }) == "quickfix" then
				local last_line = api.nvim_buf_line_count(buf)
				api.nvim_win_set_cursor(win, { last_line, 0 })
				break
			end
		end
	end
end

-- ======= 对外暴露 =======

M.tasks = load_tasks_from_dir("tasks")

function M.run_job(cmd, opts)
	local function wrap_handler(handler)
		return function(_, data)
			if data and type(data) == "table" then
				append_to_qf(data)
				if handler then
					handler(data)
				end
			end
		end
	end

	local default_opts = {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = wrap_handler(opts.on_stdout),
		on_stderr = wrap_handler(opts.on_stderr),
		on_exit = opts.on_exit,
	}

	return vim.fn.jobstart(cmd, default_opts)
end

function M.run_task(task)
	if not task or type(task.run) ~= "function" then
		vim.notify("无效的任务", vim.log.levels.ERROR)
		return
	end
	vim.fn.setqflist({}, " ", { title = "Build Output", lines = { "任务执行中..." } })
	vim.cmd("copen")
	vim.cmd("wincmd J")
	local job_id = task.run()
	if not job_id or job_id == 0 then
		vim.notify("启动任务失败", vim.log.levels.ERROR)
	end
end

function M.build()
	local project_type = detect_project_type()
	if not project_type then
		vim.notify("未识别项目类型", vim.log.levels.WARN)
		return
	end

	setup_errorformat(project_type)

	local available_tasks = {}
	for _, task in ipairs(M.tasks) do
		if task.project_type == project_type then
			table.insert(available_tasks, task)
		end
	end

	if #available_tasks == 0 then
		vim.notify("没有可用构建任务", vim.log.levels.WARN)
		return
	end

	vim.ui.select(available_tasks, {
		prompt = "选择构建任务",
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
