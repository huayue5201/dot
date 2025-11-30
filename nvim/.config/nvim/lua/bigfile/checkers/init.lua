local M = {}

-- 统一默认配置
M.defaults = {
	size = {
		max_bytes = 10 * 1024 * 1024, -- 10MB
	},
	lines = {
		max_lines = 10000,
	},
	long_line = {
		max_length = 10000,
		workers = 4,
		chunk_size = nil,
		min_chunk = 500,
		max_chunk = 20000,
		schedule_delay = 0,
	},
}

-- 检测器注册表
M.rules = {
	size = {
		check = require("bigfile.checkers.size").check,
		settings = "size",
	},
	lines = {
		check = require("bigfile.checkers.line").check,
		settings = "lines",
	},
	long_line = {
		check = require("bigfile.checkers.long_line").check,
		settings = "long_line",
	},
}

-- 获取统一配置（确保关键配置不为nil）
function M.get_config(checker_name, user_ctx)
	local defaults = M.defaults[checker_name] or {}
	local ctx = user_ctx or {}

	-- 深度合并配置
	local config = vim.tbl_deep_extend("force", {}, defaults, ctx)

	-- 确保关键配置字段不为nil
	if checker_name == "size" and config.max_bytes == nil then
		config.max_bytes = defaults.max_bytes
	end
	if checker_name == "lines" and config.max_lines == nil then
		config.max_lines = defaults.max_lines
	end
	if checker_name == "long_line" and config.max_length == nil then
		config.max_length = defaults.max_length
	end

	return config
end

-- 获取设置模块
function M.get_settings_module(checker_name)
	local checker = M.rules[checker_name]
	if not checker or not checker.settings then
		return nil
	end

	local ok, mod = pcall(require, "bigfile.settings." .. checker.settings)
	if ok then
		return mod
	end
	return nil
end

-- 统一的检测接口
function M.detect(buf, ctx, callback)
	ctx = ctx or {}
	local results = {}
	local pending = 0
	local hit_any = false

	for name, rule in pairs(M.rules) do
		if rule.check then
			pending = pending + 1
			-- 使用合并后的配置，确保包含所有必需字段
			local rule_ctx = M.get_config(name, ctx[name] or {})

			rule.check(buf, rule_ctx, function(hit, reason)
				if hit then
					hit_any = true
					results[name] = reason
				end
				pending = pending - 1
				if pending == 0 and callback then
					callback(hit_any, results)
				end
			end)
		end
	end

	-- 如果没有检测器，立即回调
	if pending == 0 and callback then
		callback(false, {})
	end
end

return M
