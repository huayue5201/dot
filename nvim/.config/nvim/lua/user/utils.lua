-- /user/utils.lua

local M = {}

-- 判断插件是否已加载
function M.is_plugin_loaded(plugin_name)
	return vim.fn.exists(":packadd " .. plugin_name) == 1
end

-- 判断插件是否正在运行
function M.is_plugin_running(plugin_name)
	local loaded = M.is_plugin_loaded(plugin_name)
	if not loaded then
		return false
	end

	local plugin_status = vim.fn["loaded_" .. plugin_name]
	if type(plugin_status) == "number" then
		return plugin_status == 1
	end

	return false
end

return M
