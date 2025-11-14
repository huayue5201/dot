local state = require("bigfile.state")
local checkers = require("bigfile.checkers")
local notifier = require("bigfile.notifier")

local M = {}

-- 强制重置所有规则状态（手动恢复小文件配置）
function M.force_reset_all()
	local buf = vim.api.nvim_get_current_buf()

	for name, _ in pairs(checkers.rules) do
		local settings_mod = checkers.get_settings_module(name)
		if settings_mod and settings_mod.reset then
			settings_mod.reset(buf)
		end
		state.set_rule_state(buf, name, false)
	end

	local notification = notifier.generate_manual_notification(buf, "force_reset")
	vim.notify(notification, vim.log.levels.INFO, { title = "BigFile" })
end

-- 强制应用所有规则的大文件配置
function M.force_apply_all()
	local buf = vim.api.nvim_get_current_buf()

	for name, _ in pairs(checkers.rules) do
		local settings_mod = checkers.get_settings_module(name)
		if settings_mod and settings_mod.apply then
			settings_mod.apply(buf)
		end
		state.set_rule_state(buf, name, true)
	end

	local notification = notifier.generate_manual_notification(buf, "force_apply")
	vim.notify(notification, vim.log.levels.WARN, { title = "BigFile" })
end

-- 显示当前状态
function M.show_status()
	local buf = vim.api.nvim_get_current_buf()
	local bigfile_rules = state.get_all_bigfile_rules(buf)

	if #bigfile_rules > 0 then
		local rule_names = {}
		for _, rule in ipairs(bigfile_rules) do
			local settings_mod = checkers.get_settings_module(rule)
			table.insert(rule_names, settings_mod and settings_mod.name or rule)
		end

		local notification = string.format("📊 当前处于大文件模式: %s", table.concat(rule_names, ", "))
		vim.notify(notification, vim.log.levels.INFO, { title = "BigFile Status" })
	else
		vim.notify("📊 当前处于小文件模式", vim.log.levels.INFO, { title = "BigFile Status" })
	end
end

-- 创建用户命令
function M.setup_commands()
	vim.api.nvim_create_user_command(
		"BigFileForceReset",
		M.force_reset_all,
		{ desc = "Force reset all BigFile rules to small file configuration" }
	)

	vim.api.nvim_create_user_command(
		"BigFileForceApply",
		M.force_apply_all,
		{ desc = "Force apply all BigFile rules to big file configuration" }
	)

	vim.api.nvim_create_user_command(
		"BigFileStatus",
		M.show_status,
		{ desc = "Show current BigFile status for the buffer" }
	)
end

return M
