-- lua/BrickDAG/bricks/frame/make.lua
local MakeFramework = {
	name = "make",
	brick_type = "frame",
	description = "异步执行Make任务的框架积木",
}

--- 异步执行make任务
--- @param exec_context table 执行上下文
--- @return boolean success
--- @return string? error_message
function MakeFramework.execute(exec_context)
	-- 获取依赖服务
	local services = exec_context.services
	local config = exec_context.config
	local resolver = services.resolver
	local logger = services.logger

	-- 解析参数
	local resolved = resolver.resolve_parameters(config, {
		project_root = vim.fn.getcwd(),
	})

	-- 获取基础积木解析后的值
	local cmd = resolved.cmd or "make"
	local args = resolved.args or {}
	local env = resolved.env or {}
	local targets = resolved.targets or {}

	-- 如果指定了targets，则将其作为额外的参数
	if #targets > 0 then
		for _, target in ipairs(targets) do
			table.insert(args, target)
		end
	end

	-- 确保所有参数都是字符串
	local safe_args = {}
	for _, arg in ipairs(args) do
		if type(arg) == "string" then
			table.insert(safe_args, arg)
		else
			table.insert(safe_args, tostring(arg))
		end
	end

	-- 构造完整命令
	local full_cmd = cmd
	if #safe_args > 0 then
		full_cmd = full_cmd .. " " .. table.concat(safe_args, " ")
	end

	logger("[MAKE] 开始异步执行: " .. full_cmd, vim.log.levels.INFO)

	-- 设置环境变量
	local original_env = {}
	for k, v in pairs(env) do
		original_env[k] = vim.env[k]
		vim.env[k] = v
	end

	-- 创建异步任务
	local job_id = vim.fn.jobstart(full_cmd, {
		on_stdout = function(_, data, _)
			for _, line in ipairs(data) do
				if line ~= "" then
					logger(line, vim.log.levels.INFO)
				end
			end
		end,
		on_stderr = function(_, data, _)
			for _, line in ipairs(data) do
				if line ~= "" then
					logger(line, vim.log.levels.ERROR)
				end
			end
		end,
		on_exit = function(_, exit_code, _)
			-- 恢复环境变量
			for k, v in pairs(original_env) do
				if v == nil then
					vim.env[k] = nil
				else
					vim.env[k] = v
				end
			end

			-- 处理结果
			if exit_code == 0 then
				logger("[MAKE] 任务成功完成", vim.log.levels.INFO)
				exec_context.global_context:mark_completed(exec_context.task_id)
			else
				local err_msg = "任务执行失败 (退出码: " .. exit_code .. ")"
				logger(err_msg, vim.log.levels.ERROR)
				exec_context.global_context:mark_failed(exec_context.task_id, err_msg)
			end

			-- 通知任务执行器完成
			if exec_context.on_done then
				exec_context.on_done(exit_code == 0)
			end
		end,
	})

	-- 检查任务是否启动成功
	if job_id <= 0 then
		-- 恢复环境变量
		for k, v in pairs(original_env) do
			if v == nil then
				vim.env[k] = nil
			else
				vim.env[k] = v
			end
		end

		local err_msg = "无法启动任务: " .. full_cmd
		logger(err_msg, vim.log.levels.ERROR)
		return false, err_msg
	end

	-- 返回任务已启动
	return true, "任务已启动"
end

return MakeFramework
