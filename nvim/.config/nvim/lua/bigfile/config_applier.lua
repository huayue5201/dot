-- lua/bigfile/config_applier.lua
local M = {}

-- 应用配置到指定缓冲区
function M.apply_config(config_table, buf)
	if not config_table or not config_table.configs then
		return
	end

	-- 保存当前缓冲区
	local current_buf = vim.api.nvim_get_current_buf()
	local switch_back = current_buf ~= buf

	-- 切换到目标缓冲区
	if switch_back then
		vim.api.nvim_set_current_buf(buf)
	end

	-- 执行所有配置项
	for _, config_func in ipairs(config_table.configs) do
		M.execute_config(config_func, buf)
	end

	-- 切换回原缓冲区
	if switch_back then
		vim.api.nvim_set_current_buf(current_buf)
	end
end

-- 执行单个配置函数
function M.execute_config(config_func, buf)
	if type(config_func) == "function" then
		-- 直接执行配置函数
		local success, err = pcall(config_func, buf)
		if not success then
			vim.notify(string.format("[bigfile] Config function failed: %s", err), vim.log.levels.WARN)
		end
	elseif type(config_func) == "string" then
		-- 向后兼容：执行字符串配置（不建议使用）
		local clean_line = config_func:gsub("%-%-.*$", ""):gsub("^%s*(.-)%s*$", "%1")
		if clean_line == "" then
			return
		end

		local success, err = pcall(function()
			loadstring(clean_line)()
		end)

		if not success then
			vim.notify(
				string.format("[bigfile] Failed to execute config: %s\nError: %s", clean_line, err),
				vim.log.levels.WARN
			)
		end
	else
		vim.notify("[bigfile] Invalid config type: " .. type(config_func), vim.log.levels.WARN)
	end
end

return M
