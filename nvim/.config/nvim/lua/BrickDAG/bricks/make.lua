-- bricks/make.lua
local MakeFramework = {
	name = "make",
	brick_type = "frame", -- 标识为框架积木
	description = "执行Make任务的框架积木",
}

-- 执行make任务
--- @param exec_context table 执行上下文
--- @return boolean success
--- @return string? error_message
function MakeFramework.execute(exec_context)
	-- 获取依赖服务
	local services = exec_context.services
	local config = exec_context.config

	-- 解析参数（使用依赖注入的解析器）
	local resolved = services.resolver.resolve_parameters(config, {
		project_root = vim.fn.getcwd(),
	})

	-- 构造命令
	local cmd = resolved.cmd or "make"
	local args = resolved.args or {}

	-- 创建完整命令
	local full_cmd = cmd
	if #args > 0 then
		full_cmd = full_cmd .. " " .. table.concat(args, " ")
	end

	-- 使用依赖注入的logger
	services.logger("[MAKE] 执行命令: " .. full_cmd, vim.log.levels.INFO)

	-- 执行命令
	local output = vim.fn.system(full_cmd)
	local exit_code = vim.v.shell_error

	-- 检查执行结果
	if exit_code == 0 then
		return true, output
	else
		return false, "命令执行失败 (退出码: " .. exit_code .. ")\n输出: " .. output
	end
end

return MakeFramework
