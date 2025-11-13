local M = {}

local state = {}

-- 添加检测结果
function M.add(buf, rule_name, reason, disabled_options, disabled_plugins)
	state[buf] = state[buf] or { rules = {} }
	state[buf].rules[rule_name] = {
		reason = reason or "",
		disabled_options = disabled_options or {},
		disabled_plugins = disabled_plugins or {},
		time = os.date("%H:%M:%S"),
	}
end

-- 清除缓冲区信息
function M.clear(buf)
	state[buf] = nil
end

function M.get(buf)
	return state[buf]
end

function M.get_triggered_rules(buf)
	local info = state[buf]
	if not info or not info.rules then
		return {}
	end
	local triggered = {}
	for rule_name, rule_info in pairs(info.rules) do
		table.insert(triggered, {
			name = rule_name,
			reason = rule_info.reason,
			disabled_options = rule_info.disabled_options,
			disabled_plugins = rule_info.disabled_plugins,
			time = rule_info.time,
		})
	end
	return triggered
end

-- 展示信息
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
		table.insert(messages, { "" .. rule_name .. ":\n", "Keyword" })

		if #rule_info.disabled_options > 0 then
			table.insert(messages, { table.concat(rule_info.disabled_options, "󱞣\n"), "Type" })
		end

		table.insert(messages, { "\n" .. rule_info.reason, "String" })

		if #rule_info.disabled_plugins > 0 then
			table.insert(messages, { "\n🔌 " .. table.concat(rule_info.disabled_plugins, "."), "Identifier" })
		end

		table.insert(messages, { "\n   🕒" .. "\n" .. rule_info.time, "Comment" })
		table.insert(messages, { "", "Normal" })
	end

	vim.api.nvim_echo(messages, false, {})
end

return M
