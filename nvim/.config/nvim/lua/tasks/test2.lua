return {
	id = "test_task",
	label = "完整功能测试任务",
	description = "这个任务演示了任务系统的所有功能",

	-- 命令可以是字符串或函数（支持参数化）
	cmd = function(params)
		local parts = {}

		-- 基本命令部分
		table.insert(parts, "echo '===== 任务开始 ====='")

		-- 显示参数
		table.insert(parts, string.format("echo '参数: mode=%s, count=%d'", params.mode, params.count))

		-- 显示环境变量
		table.insert(parts, "echo '环境变量:'")
		table.insert(parts, "echo '  TASK_ENV: $TASK_ENV'")
		table.insert(parts, "echo '  GLOBAL_ENV: $GLOBAL_ENV'")
		table.insert(parts, "echo '  CUSTOM_ENV: $CUSTOM_ENV'")

		-- 模拟长时间运行
		table.insert(parts, string.format("echo '运行时间: %d秒'", params.duration))
		table.insert(parts, string.format("sleep %d", params.duration))

		-- 根据模式模拟不同结果
		if params.mode == "success" then
			table.insert(parts, "echo '===== 任务成功完成 ====='")
			table.insert(parts, "exit 0")
		elseif params.mode == "fail" then
			table.insert(parts, "echo '===== 任务失败 ====='")
			table.insert(parts, "exit 1")
		elseif params.mode == "timeout" then
			table.insert(parts, "echo '===== 任务将超时 ====='")
			table.insert(parts, "sleep 30") -- 确保超过超时时间
			table.insert(parts, "exit 0")
		end

		return table.concat(parts, "; ")
	end,

	-- 任务参数定义
	params = {
		mode = "success", -- 任务模式: success/fail/timeout
		count = 3, -- 迭代次数
		duration = 2, -- 运行时间(秒)
	},

	-- 环境变量
	env = {
		TASK_ENV = "任务环境变量值",
	},

	-- 超时设置(秒)
	timeout = 5,

	-- 任务依赖
	depends_on = { "dependency_task" },

	-- 回调函数
	on_output = function(data, is_error)
		-- 实时输出处理
		if is_error then
			vim.notify("错误输出: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
		else
			vim.notify("任务输出: " .. table.concat(data, "\n"), vim.log.levels.INFO)
		end
	end,

	on_start = function()
		vim.notify("任务开始执行", vim.log.levels.INFO)
	end,

	on_complete = function(output)
		vim.notify("任务成功完成! 输出行数: " .. #output, vim.log.levels.INFO)
	end,

	on_fail = function(output)
		vim.notify("任务执行失败! 最后输出: " .. output[#output], vim.log.levels.ERROR)
	end,

	on_timeout = function()
		vim.notify("任务执行超时!", vim.log.levels.WARN)
	end,
}
