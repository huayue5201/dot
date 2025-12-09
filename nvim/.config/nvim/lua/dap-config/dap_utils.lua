local M = {}

local dap = require("dap")

function M.set_debuglog()
	local levels = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
	vim.ui.select(levels, {
		prompt = "📊 选择 DAP 日志级别:",
		format_item = function(item)
			local desc = {
				TRACE = "追踪：最详细的日志信息",
				DEBUG = "调试：调试信息",
				INFO = "信息：一般信息，默认级别",
				WARN = "警告：警告信息",
				ERROR = "错误：错误信息",
			}
			-- 增加间距，确保输出整洁
			return string.format("📝 %-10s . %s", item, desc[item])
		end,
	}, function(choice)
		if choice then
			dap.set_log_level(choice)
			print(string.format("✔️ DAP 日志级别设置为: %s", choice))
		else
			print("❌ 未选择日志级别，操作已取消")
		end
	end)
end

function M.set_breakpoint()
	vim.ui.select({
		"条件断点",
		"命中次数",
		"日志点",
		"多条件断点",
	}, {
		prompt = "⚡ 选择断点类型:",
		format_item = function(item)
			local descriptions = {
				["条件断点"] = "满足条件时才触发",
				["命中次数"] = "设置触发次数",
				["日志点"] = "触发时输出日志",
				["多条件断点"] = "多个条件组合触发",
			}
			-- 使用固定宽度，确保描述内容对齐，右对齐描述内容
			return string.format("󰁯  %-10s . %-15s", item, descriptions[item])
		end,
	}, function(choice)
		if choice == "条件断点" then
			vim.ui.input({
				prompt = "⏳ 输入条件: ",
			}, function(condition)
				if condition and condition ~= "" then
					dap.toggle_breakpoint(condition)
					print(string.format("✔️ 条件断点已设置：%s", condition))
				else
					vim.notify("⚠️ 条件不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "命中次数" then
			vim.ui.input({ prompt = "🔢 输入次数: " }, function(hit_count)
				local num = tonumber(hit_count)
				if num then
					dap.toggle_breakpoint(nil, tostring(num))
					print(string.format("✔️ 命中次数：%d", num))
				else
					vim.notify("⚠️ 请输入有效的数字！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "日志点" then
			vim.ui.input({ prompt = "📝 输入日志: " }, function(message)
				if message and message ~= "" then
					dap.toggle_breakpoint(nil, nil, message)
					print(string.format("✔️ 日志已设置：%s", message))
				else
					vim.notify("⚠️ 日志内容不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "多条件断点" then
			vim.ui.input({ prompt = "🔗 输入条件,次数,日志: " }, function(input)
				if not input or input == "" then
					vim.notify("⚠️ 输入不能为空！", vim.log.levels.ERROR)
					return
				end

				-- 处理多条件输入
				input = input:match("^%s*(.-)%s*$")
				input = input:gsub("\\,", "COMMA")
				local parts = {}
				for part in input:gmatch("([^,]+)") do
					part = part:gsub("COMMA", ","):match("^%s*(.-)%s*$")
					table.insert(parts, part)
				end

				local condition, hitCondition, logMessage = parts[1], parts[2], parts[3]

				if condition == "nil" then
					condition = nil
				end
				if hitCondition == "nil" then
					hitCondition = nil
				end
				if logMessage == "nil" then
					logMessage = nil
				end

				if hitCondition and not tonumber(hitCondition) then
					vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
					return
				end

				dap.toggle_breakpoint(condition, hitCondition, logMessage)
				print(
					string.format(
						"✔️ 多条件断点已设置：%-20s %-10s %-20s",
						condition or "无条件",
						hitCondition or "无次数",
						logMessage or "无日志"
					)
				)
			end)
		end
	end)
end
return M
