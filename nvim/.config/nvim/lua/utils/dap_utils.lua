local M = {}

local dap = require("dap")

function M.set_debuglog()
	local levels = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
	vim.ui.select(levels, {
		prompt = "选择 DAP 日志级别:",
		format_item = function(item)
			local desc = {
				TRACE = "追踪，最详细的日志信息",
				DEBUG = "调试信息",
				INFO = "一般信息，默认级别",
				WARN = "警告信息",
				ERROR = "错误信息",
			}
			return item .. " — " .. desc[item]
		end,
	}, function(choice)
		if choice then
			dap.set_log_level(choice)
			print("DAP 日志级别设置为: " .. choice)
		else
			print("未选择日志级别，操作取消")
		end
	end)
end

function M.set_breakpoint()
	vim.ui.select({ "条件断点", "命中次数", "日志点", "多条件断点" }, {
		prompt = "选择断点类型:",
	}, function(choice)
		-----------------------------------------------------------------------
		-- 条件断点
		-----------------------------------------------------------------------
		if choice == "条件断点" then
			vim.ui.input({ prompt = "󰌓 输入条件: " }, function(condition)
				if condition and condition ~= "" then
					dap.toggle_breakpoint(condition) -- condition 是字符串
				else
					vim.notify("条件不能为空！", vim.log.levels.ERROR)
				end
			end)

		-----------------------------------------------------------------------
		-- 命中次数断点
		-----------------------------------------------------------------------
		elseif choice == "命中次数" then
			vim.ui.input({ prompt = "󰌓 输入次数（数字）: " }, function(hit_count)
				local num = tonumber(hit_count)
				if num then
					dap.toggle_breakpoint(nil, tostring(num)) -- hitCondition 必须是字符串
				else
					vim.notify("请输入有效数字！", vim.log.levels.ERROR)
				end
			end)

		-----------------------------------------------------------------------
		-- 日志断点
		-----------------------------------------------------------------------
		elseif choice == "日志点" then
			vim.ui.input({ prompt = "󰌓 输入日志内容: " }, function(message)
				if message and message ~= "" then
					dap.toggle_breakpoint(nil, nil, message) -- logMessage 必须是字符串
				else
					vim.notify("日志内容不能为空！", vim.log.levels.ERROR)
				end
			end)

		-----------------------------------------------------------------------
		-- 多条件断点 (condition, hitCondition, logMessage)
		-----------------------------------------------------------------------
		elseif choice == "多条件断点" then
			vim.ui.input({ prompt = "󰌓 输入多条件（格式：条件,次数,日志）: " }, function(input)
				if not input or input == "" then
					vim.notify("输入不能为空！", vim.log.levels.ERROR)
					return
				end

				-- 去除前后空格
				input = input:match("^%s*(.-)%s*$")

				-- 支持逗号转义：\, → COMMA
				input = input:gsub("\\,", "COMMA")

				local parts = {}
				for part in input:gmatch("([^,]+)") do
					part = part:gsub("COMMA", ",")
					part = part:match("^%s*(.-)%s*$")
					table.insert(parts, part)
				end

				local condition = parts[1]
				local hitCondition = parts[2]
				local logMessage = parts[3]

				-- nil 字符串转换
				if condition == "nil" then
					condition = nil
				end
				if hitCondition == "nil" then
					hitCondition = nil
				end
				if logMessage == "nil" then
					logMessage = nil
				end

				-- hitCondition 必须是字符串数字
				if hitCondition ~= nil then
					if not tonumber(hitCondition) then
						vim.notify("命中次数必须是数字或 nil！", vim.log.levels.ERROR)
						return
					end
					hitCondition = tostring(hitCondition)
				end

				dap.toggle_breakpoint(condition, hitCondition, logMessage)
			end)
		end
	end)
end
return M
