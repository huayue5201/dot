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
	for _, config_line in ipairs(config_table.configs) do
		M.execute_config_line(config_line)
	end

	-- 切换回原缓冲区
	if switch_back then
		vim.api.nvim_set_current_buf(current_buf)
	end
end

-- 执行单个配置行
function M.execute_config_line(config_line)
	if type(config_line) ~= "string" then
		return
	end

	-- 清理配置行（移除注释和多余空格）
	local clean_line = config_line:gsub("%-%-.*$", ""):gsub("^%s*(.-)%s*$", "%1")

	-- 跳过空行
	if clean_line == "" then
		return
	end

	-- 执行配置
	local success, err = pcall(function()
		loadstring(clean_line)()
	end)

	if not success then
		vim.notify(
			string.format("[bigfile] Failed to execute config: %s\nError: %s", clean_line, err),
			vim.log.levels.WARN
		)
	end
end

return M
