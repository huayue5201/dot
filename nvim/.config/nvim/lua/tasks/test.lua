-- ~/.config/nvim/lua/tasks/test.lua

return {
	id = "test",
	label = "系统测试任务",
	cmd = function(params)
		-- 简化命令，避免使用 sleep（在 Windows 上可能不兼容）
		local mode = params and params.mode or "basic"

		if mode == "basic" then
			return { "echo", "基本测试任务执行中..." }
		elseif mode == "error" then
			return { "this_command_does_not_exist" }
		elseif mode == "long" then
			return {
				"echo",
				"开始长时间任务...",
				"&&",
				"echo",
				"第一阶段完成",
				"&&",
				"echo",
				"任务完成",
			}
		end
	end,

	env = {
		TEST_ENV = "TaskMasterTest",
	},

	on_start = function()
		vim.notify("测试任务开始执行...")
	end,

	on_output = function(data, is_error)
		for _, line in ipairs(data) do
			if line ~= "" then
				vim.notify(line, is_error and vim.log.levels.ERROR or vim.log.levels.INFO)
			end
		end
	end,

	on_complete = function(output)
		vim.notify("测试任务成功完成!")
	end,

	on_fail = function(output)
		vim.notify("测试任务失败!", vim.log.levels.ERROR)
		vim.notify("输出内容: " .. table.concat(output, "\n"), vim.log.levels.INFO)
	end,
}
