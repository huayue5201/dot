-- lua/bigfile/state.lua
local M = {}

-- 统一状态存储：buf -> { rules = { rule_name = { applied, reason, time } } }
local state = setmetatable({}, { __mode = "k" })

-- 设置规则状态
function M.set_rule_state(buf, rule_name, applied, reason)
	if not state[buf] then
		state[buf] = { rules = {} }
	end

	state[buf].rules[rule_name] = {
		applied = applied,
		reason = reason or "",
		time = os.date("%H:%M:%S"),
	}
end

-- 获取规则状态
function M.get_rule_state(buf, rule_name)
	return state[buf] and state[buf].rules[rule_name] and state[buf].rules[rule_name].applied or false
end

-- 检查是否有任何规则处于大文件状态
function M.has_any_bigfile_state(buf)
	if not state[buf] then
		return false
	end

	for _, rule_info in pairs(state[buf].rules) do
		if rule_info.applied then
			return true
		end
	end

	return false
end

-- 获取所有处于大文件状态的规则名
function M.get_all_bigfile_rules(buf)
	if not state[buf] then
		return {}
	end

	local rules = {}
	for rule_name, rule_info in pairs(state[buf].rules) do
		if rule_info.applied then
			table.insert(rules, rule_name)
		end
	end
	return rules
end

-- 获取触发的规则详细信息
function M.get_triggered_rules(buf)
	if not state[buf] then
		return {}
	end

	local triggered = {}
	for rule_name, rule_info in pairs(state[buf].rules) do
		if rule_info.applied then
			table.insert(triggered, {
				name = rule_name,
				reason = rule_info.reason,
				time = rule_info.time,
			})
		end
	end
	return triggered
end

-- 显示状态信息
function M.show(buf)
	local buf_info = state[buf]
	if not buf_info then
		vim.api.nvim_echo({ { "No bigfile detection results for this buffer", "WarningMsg" } }, false, {})
		return
	end

	local messages = {}

	table.insert(messages, { "   🚀BigFile\n", "Title" })
	table.insert(messages, { "", "Normal" })

	for rule_name, rule_info in pairs(buf_info.rules) do
		if rule_info.applied then
			table.insert(messages, { "" .. rule_name .. ":\n", "Keyword" })
			table.insert(messages, { rule_info.reason, "String" })
			table.insert(messages, { "\n   🕒" .. rule_info.time .. "\n", "Comment" })
			table.insert(messages, { "", "Normal" })
		end
	end

	vim.api.nvim_echo(messages, false, {})
end

-- 清理缓冲区状态
function M.clear(buf)
	state[buf] = nil
end

return M
