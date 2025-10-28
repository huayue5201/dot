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
		if choice == "条件断点" then
			vim.ui.input({ prompt = "󰌓 输入条件: " }, function(condition)
				local str_condition = tostring(condition or "")
				if str_condition ~= "" then
					dap.toggle_breakpoint(str_condition)
				else
					vim.notify("条件不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "命中次数" then
			vim.ui.input({ prompt = "󰌓 输入次数: " }, function(hit_count)
				local num_hit = tonumber(hit_count)
				if num_hit then
					dap.toggle_breakpoint(nil, num_hit)
				else
					vim.notify("无效输入次数！请输入有效的数字。", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "日志点" then
			vim.ui.input({ prompt = "󰌓 输入日志内容: " }, function(message)
				local str_message = tostring(message or "")
				if str_message ~= "" then
					dap.toggle_breakpoint(nil, nil, str_message)
				else
					vim.notify("日志内容不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "多条件断点" then
			vim.ui.input({ prompt = "󰌓 输入多条件（逗号分隔，支持转义字符）: " }, function(input)
				local conditions = {}
				if input then
					input = input:match("^%s*(.-)%s*$")
					input = input:gsub("\\,", "COMMA")
					for condition in string.gmatch(input, "([^,]+)") do
						condition = condition:gsub("COMMA", ",")
						table.insert(conditions, condition:match("^%s*(.-)%s*$"))
					end
					local condition = conditions[1]
					local hit_count = conditions[2]
					local log_message = conditions[3]
					if condition == "nil" then
						condition = nil
					end
					if hit_count == "nil" then
						hit_count = nil
					end
					if log_message == "nil" then
						log_message = nil
					end
					if hit_count ~= nil and not tonumber(hit_count) then
						vim.notify("命中次数只能是数字或nil！", vim.log.levels.ERROR)
						return
					end
					dap.toggle_breakpoint(condition, hit_count, log_message)
				end
			end)
		end
	end)
end

return M
