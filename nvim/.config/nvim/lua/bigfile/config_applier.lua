local M = {}

-- 应用配置到指定缓冲区
function M.apply_config(config, buf)
	if not config then
		return
	end

	-- 应用选项设置
	if config.options then
		for opt_name, opt_value in pairs(config.options) do
			M.apply_option(opt_name, opt_value, buf)
		end
	end

	-- 执行插件命令
	if config.plugin_commands then
		for _, cmd in ipairs(config.plugin_commands) do
			M.execute_command(cmd)
		end
	end
end

-- 应用单个选项（自动判断作用域）
function M.apply_option(opt_name, opt_value, buf)
	local success, err = pcall(function()
		local win = vim.fn.bufwinid(buf)

		-- 按作用域优先级尝试设置选项
		if win ~= -1 then
			-- 先尝试窗口选项
			pcall(vim.api.nvim_set_option_value, opt_name, opt_value, { win = win })
		end

		-- 再尝试缓冲区选项
		pcall(vim.api.nvim_set_option_value, opt_name, opt_value, { buf = buf })

		-- 最后尝试全局选项
		pcall(function()
			vim.o[opt_name] = opt_value
		end)
	end)

	if not success then
		vim.notify(string.format("[bigfile] Failed to set option %s: %s", opt_name, err), vim.log.levels.WARN)
	end
end

-- 执行命令（支持 Vim 命令和 Lua 代码）
function M.execute_command(cmd)
	local success, err = pcall(function()
		if cmd:sub(1, 4) == "lua " then
			loadstring(cmd:sub(5))()
		else
			vim.cmd(cmd)
		end
	end)

	if not success then
		vim.notify(string.format("[bigfile] Failed to execute command: %s", err), vim.log.levels.WARN)
	end
end

return M
