-- lua/utils/neotask.lua
local uv = vim.loop
local api = vim.api

local program_binary = require("utils.program_binary")

local M = {}

--- 封装任务运行逻辑
function M.run_job(cmd, opts)
	local function wrap_handler(handler)
		return function(_, data)
			if data and type(data) == "table" then
				M.append_to_qf(data)
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

M.tasks = {
	{
		name = "Make",
		label = "make",
		project_type = "make",
		run = function()
			return M.run_job("make", {
				on_exit = function(_, code)
					if code == 0 then
						vim.notify("✔️ make 构建成功", vim.log.levels.INFO)
					else
						vim.notify("❌ make 构建失败，请查看 Quickfix", vim.log.levels.ERROR)
					end
				end,
			})
		end,
	},
	{
		name = "Make Clean",
		label = "make clean",
		project_type = "make",
		run = function()
			return M.run_job("make clean", {
				on_exit = function(_, code)
					if code == 0 then
						vim.notify("✔️ clean 成功", vim.log.levels.INFO)
					else
						vim.notify("❌ clean 失败", vim.log.levels.ERROR)
					end
				end,
			})
		end,
	},
	{
		name = "Load Date",
		label = "Load Date (make + openocd)",
		project_type = "make",
		run = function()
			return M.run_job("make", {
				on_exit = function(_, code)
					if code ~= 0 then
						vim.notify("❌ make 构建失败，终止 Load Date", vim.log.levels.ERROR)
						return
					end
					local elf_file = program_binary.safe_get_program_binary("elf")
					if not elf_file or elf_file == "" then
						vim.notify("找不到 ELF 文件，终止 Load Date", vim.log.levels.ERROR)
						return
					end
					local openocd_cmd = {
						"openocd",
						"-f",
						"interface/stlink.cfg",
						"-f",
						"target/stm32f1x.cfg",
						"-c",
						"program " .. elf_file .. " verify reset exit",
					}
					M.run_job(openocd_cmd, {
						on_exit = function(_, code)
							if code == 0 then
								vim.notify("✔️ Load Date 任务完成", vim.log.levels.INFO)
							else
								vim.notify("❌ Load Date 任务失败", vim.log.levels.ERROR)
							end
						end,
					})
				end,
			})
		end,
	},
	{
		name = "compiledb make",
		label = "compiledb make",
		project_type = "make",
		run = function()
			return M.run_job({ "compiledb", "make" }, {
				on_exit = function(_, code)
					if code == 0 then
						vim.notify("✔️ compiledb make 执行成功", vim.log.levels.INFO)
					else
						vim.notify("❌ compiledb make 执行失败", vim.log.levels.ERROR)
					end
				end,
			})
		end,
	},
}

function M.detect_project_type()
	if uv.fs_stat("Makefile") then
		return "make"
	elseif uv.fs_stat("Cargo.toml") then
		return "cargo"
	end
	return nil
end

function M.setup_errorformat(project_type)
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

function M.append_to_qf(data)
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
	local project_type = M.detect_project_type()
	if not project_type then
		vim.notify("未识别项目类型", vim.log.levels.WARN)
		return
	end

	M.setup_errorformat(project_type)

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

api.nvim_create_user_command("ProjectBuild", function()
	M.build()
end, {})

return M
