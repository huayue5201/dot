-- lua/dap-config/dap_utils.lua
local dap = require("dap")

local M = {}

local function sync_after_set()
	vim.defer_fn(function()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, 10)
end

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
		"Conditional",
		"Hit Count",
		"Log Point",
		"Multi",
	}, {
		prompt = " 🔴选择断点类型: ",
		format_item = function(item)
			local descriptions = {
				["Conditional"] = "满足条件时才触发",
				["Hit Count"] = "设置触发次数",
				["Log Point"] = "触发时输出日志",
				["Multi"] = "多个条件组合触发",
			}
			return string.format("󰁯  %-15s . %s", item, descriptions[item])
		end,
	}, function(choice)
		if not choice then
			return
		end

		if choice == "Conditional" then
			vim.ui.input({ prompt = "⏳ 输入条件: " }, function(condition)
				if condition and condition ~= "" then
					dap.toggle_breakpoint(condition)
					print("✔️ 条件断点已设置：" .. condition)
					sync_after_set()
				else
					vim.notify("⚠️ 条件不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "Hit Count" then
			vim.ui.input({ prompt = "🔢 输入次数: " }, function(hit_count)
				local num = tonumber(hit_count)
				if num then
					dap.toggle_breakpoint(nil, tostring(num))
					print("✔️ 命中次数：" .. num)
					sync_after_set()
				else
					vim.notify("⚠️ 请输入有效的数字！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "Log Point" then
			vim.ui.input({ prompt = "📝 输入日志: " }, function(message)
				if message and message ~= "" then
					dap.toggle_breakpoint(nil, nil, message)
					print("✔️ 日志已设置：" .. message)
					sync_after_set()
				else
					vim.notify("⚠️ 日志内容不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "Multi" then
			local inputs = {
				condition = { prompt = "⏳ 条件（可选）", default = "" },
				hit_count = { prompt = "🔢 命中次数（可选）", default = "" },
				log_message = { prompt = "📝 日志消息（可选）", default = "" },
			}
			local results, order = {}, { "condition", "hit_count", "log_message" }

			local function collect(i)
				if i > #order then
					local condition = results.condition ~= "" and results.condition or nil
					local hitCondition = results.hit_count ~= "" and results.hit_count or nil
					local logMessage = results.log_message ~= "" and results.log_message or nil

					if hitCondition and not tonumber(hitCondition) then
						vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
						results.hit_count = nil
						collect(2)
						return
					end

					dap.toggle_breakpoint(condition, hitCondition, logMessage)
					print(
						("✔️ 多条件断点已设置：条件=%s 次数=%s 日志=%s"):format(
							condition or "无条件",
							hitCondition or "无次数限制",
							logMessage or "无日志"
						)
					)
					sync_after_set()
					return
				end

				local key, spec = order[i], inputs[order[i]]
				vim.ui.input({ prompt = spec.prompt .. ": ", default = spec.default }, function(input)
					results[key] = input or ""
					collect(i + 1)
				end)
			end

			collect(1)
		end
	end)
end

return M
