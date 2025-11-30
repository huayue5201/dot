local uv = vim.loop
local checkers = require("bigfile.checkers")
local state = require("bigfile.state")

local M = {}

-- 白名单设置
local whitelist = {
	ft = { "help", "NvimTree", "toggleterm", "qf" },
	buftype = { "nofile", "terminal", "quickfix" },
}

-- 弱引用表管理 timers
local timers = setmetatable({}, { __mode = "k" })
local last_line_count = setmetatable({}, { __mode = "k" })
local pending_detection = setmetatable({}, { __mode = "k" })

-- 检查 buf 是否在白名单中
local function is_whitelisted(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return true
	end

	local ft = vim.api.nvim_buf_get_option(buf, "filetype")
	local bt = vim.api.nvim_buf_get_option(buf, "buftype")

	for _, v in ipairs(whitelist.ft) do
		if v == ft then
			return true
		end
	end

	for _, v in ipairs(whitelist.buftype) do
		if v == bt then
			return true
		end
	end

	return false
end

-- 清理指定缓冲区的定时器
local function cleanup_timer(buf)
	if timers[buf] and not timers[buf]:is_closing() then
		timers[buf]:stop()
		timers[buf]:close()
	end
	timers[buf] = nil

	if pending_detection[buf] and not pending_detection[buf]:is_closing() then
		pending_detection[buf]:stop()
		pending_detection[buf]:close()
	end
	pending_detection[buf] = nil

	last_line_count[buf] = nil
end

-- 显示汇总通知
local function show_summary_notification(buf, triggered_rules, recovered_rules)
	local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
	if #triggered_rules == 0 and #recovered_rules == 0 then
		return
	end

	local messages = {}
	if #triggered_rules > 0 then
		local rule_names = {}
		for _, rule in ipairs(triggered_rules) do
			local settings_mod = checkers.get_settings_module(rule.name)
			table.insert(rule_names, settings_mod and settings_mod.name or rule.name)
		end
		table.insert(messages, string.format("📦 大文件: %s", table.concat(rule_names, ", ")))
	end

	if #recovered_rules > 0 then
		local rule_names = {}
		for _, rule in ipairs(recovered_rules) do
			local settings_mod = checkers.get_settings_module(rule.name)
			table.insert(rule_names, settings_mod and settings_mod.name or rule.name)
		end
		table.insert(messages, string.format("✅ 恢复: %s", table.concat(rule_names, ", ")))
	end

	local notification = string.format("%s: %s", filename, table.concat(messages, "; "))
	local level = (#triggered_rules > 0) and vim.log.levels.WARN or vim.log.levels.INFO
	vim.notify(notification, level, { title = "BigFile" })
end

-- 设置粘贴检测
local function setup_paste_detection()
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
		group = vim.api.nvim_create_augroup("BigFilePasteDetection", { clear = true }),
		callback = function(args)
			local buf = args.buf
			if is_whitelisted(buf) then
				return
			end

			local current_lines = vim.api.nvim_buf_line_count(buf)
			local previous_lines = last_line_count[buf] or current_lines

			-- 检测行数大幅增加（可能是粘贴）
			local line_increase = current_lines - previous_lines
			if line_increase > 20 then
				if pending_detection[buf] then
					pending_detection[buf]:stop()
					pending_detection[buf]:close()
				end

				pending_detection[buf] = uv.new_timer()
				pending_detection[buf]:start(
					500,
					0,
					vim.schedule_wrap(function()
						pending_detection[buf] = nil
						if vim.api.nvim_buf_is_valid(buf) and not is_whitelisted(buf) then
							M.run_all_checkers(buf)
						end
					end)
				)
			end

			last_line_count[buf] = current_lines
		end,
	})
end

-- 启动防抖检测
function M.setup(opts)
	local delay = opts and opts.debounce or 200

	setup_paste_detection()

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
		group = vim.api.nvim_create_augroup("BigFileDetection", { clear = true }),
		callback = function(args)
			local buf = args.buf
			if is_whitelisted(buf) then
				return
			end

			last_line_count[buf] = vim.api.nvim_buf_line_count(buf)
			cleanup_timer(buf)

			timers[buf] = uv.new_timer()
			timers[buf]:start(
				delay,
				0,
				vim.schedule_wrap(function()
					timers[buf] = nil
					M.run_all_checkers(buf)
				end)
			)
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = vim.api.nvim_create_augroup("BigFileCleanup", { clear = true }),
		callback = function(args)
			cleanup_timer(args.buf)
			state.clear(args.buf)
		end,
	})
end

-- 执行所有检测模块（修复配置传递问题）
function M.run_all_checkers(buf)
	if not vim.api.nvim_buf_is_valid(buf) or is_whitelisted(buf) then
		return
	end

	local triggered_rules = {} -- 新触发的大文件规则
	local recovered_rules = {} -- 恢复的小文件规则
	local pending = 0

	-- 计算需要等待的检测器数量
	for name, checker in pairs(checkers.rules) do
		if checker and type(checker.check) == "function" then
			pending = pending + 1
		end
	end

	if pending == 0 then
		return
	end

	-- 执行所有检测器（修复：传递正确的配置）
	for name, checker in pairs(checkers.rules) do
		if checker and type(checker.check) == "function" then
			-- 关键修复：使用 get_config 获取正确的配置
			local rule_config = checkers.get_config(name, {})
			checker.check(buf, rule_config, function(hit, reason)
				vim.schedule(function()
					local settings_mod = checkers.get_settings_module(name)
					local previous_state = state.get_rule_state(buf, name)

					if hit then
						if not previous_state then
							if settings_mod and settings_mod.apply then
								settings_mod.apply(buf)
							end
							state.set_rule_state(buf, name, true, reason)
							table.insert(triggered_rules, { name = name, reason = reason })
						end
					else
						if previous_state then
							if settings_mod and settings_mod.reset then
								settings_mod.reset(buf)
							end
							state.set_rule_state(buf, name, false, "恢复正常")
							table.insert(recovered_rules, { name = name, reason = "恢复正常" })
						end
					end

					pending = pending - 1
					if pending == 0 then
						show_summary_notification(buf, triggered_rules, recovered_rules)
						if #triggered_rules > 0 then
							state.show(buf)
						end
					end
				end)
			end)
		else
			pending = pending - 1
		end
	end
end

return M
