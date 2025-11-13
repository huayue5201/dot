local M = {}

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

-- 统一的检测接口（保持向后兼容）
function M.detect(buf, ctx, callback)
	ctx = ctx or {}
	local results = {}
	local pending = 0
	local hit_any = false

	for name, rule in pairs(M.rules) do
		if rule.check then
			pending = pending + 1
			local rule_ctx = ctx[name] or {}
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
