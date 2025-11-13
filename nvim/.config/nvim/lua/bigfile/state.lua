local M = {}

-- 记录缓冲区的大文件状态：buf -> { rule_name = applied }
local bigfile_state = setmetatable({}, { __mode = "k" })

-- 设置规则状态
function M.set_rule_state(buf, rule_name, applied)
	if not bigfile_state[buf] then
		bigfile_state[buf] = {}
	end
	bigfile_state[buf][rule_name] = applied
end

-- 获取规则状态
function M.get_rule_state(buf, rule_name)
	return bigfile_state[buf] and bigfile_state[buf][rule_name] or false
end

-- 检查是否有任何规则处于大文件状态
function M.has_any_bigfile_state(buf)
	if not bigfile_state[buf] then
		return false
	end

	for _, applied in pairs(bigfile_state[buf]) do
		if applied then
			return true
		end
	end

	return false
end

-- 获取所有处于大文件状态的规则名
function M.get_all_bigfile_rules(buf)
	if not bigfile_state[buf] then
		return {}
	end
	local rules = {}
	for rule_name, applied in pairs(bigfile_state[buf]) do
		if applied then
			table.insert(rules, rule_name)
		end
	end
	return rules
end

-- 清理缓冲区状态
function M.clear(buf)
	bigfile_state[buf] = nil
end

return M
