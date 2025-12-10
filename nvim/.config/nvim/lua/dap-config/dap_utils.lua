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
		"Conditional",
		"Hit Count",
		"Log Point",
		"Multi",
	}, {
		prompt = "🔴 选择断点类型:",
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
		elseif choice == "Hit Count" then
			vim.ui.input({ prompt = "🔢 输入次数: " }, function(hit_count)
				local num = tonumber(hit_count)
				if num then
					dap.toggle_breakpoint(nil, tostring(num))
					print(string.format("✔️ 命中次数：%d", num))
				else
					vim.notify("⚠️ 请输入有效的数字！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "Log Point" then
			vim.ui.input({ prompt = "📝 输入日志: " }, function(message)
				if message and message ~= "" then
					dap.toggle_breakpoint(nil, nil, message)
					print(string.format("✔️ 日志已设置：%s", message))
				else
					vim.notify("⚠️ 日志内容不能为空！", vim.log.levels.ERROR)
				end
			end)
		elseif choice == "Multi" then
			-- 多条件断点：分步输入
			local inputs = {
				condition = { prompt = "⏳ 条件（可选）", default = "" },
				hit_count = { prompt = "🔢 命中次数（可选）", default = "" },
				log_message = { prompt = "📝 日志消息（可选）", default = "" },
			}

			local results = {}
			local input_order = { "condition", "hit_count", "log_message" }

			local function collect_input(index)
				if index > #input_order then
					-- 所有输入完成
					local condition = results.condition ~= "" and results.condition or nil
					local hitCondition = results.hit_count ~= "" and results.hit_count or nil
					local logMessage = results.log_message ~= "" and results.log_message or nil

					-- 验证命中次数是否为数字
					if hitCondition and not tonumber(hitCondition) then
						vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
						-- 如果验证失败，重新询问命中次数
						results.hit_count = nil
						collect_input(2) -- 重新从命中次数开始
						return
					end

					-- 设置断点
					dap.toggle_breakpoint(condition, hitCondition, logMessage)

					-- 显示设置结果
					local condition_str = condition or "无条件"
					local hit_str = hitCondition or "无次数限制"
					local log_str = logMessage or "无日志"

					print(
						string.format(
							"✔️ 多条件断点已设置：\n  条件: %s\n  次数: %s\n  日志: %s",
							condition_str,
							hit_str,
							log_str
						)
					)
					return
				end

				local key = input_order[index]
				local spec = inputs[key]

				-- 如果已经输入过且有值，直接跳到下一步
				if results[key] ~= nil then
					collect_input(index + 1)
					return
				end

				vim.ui.input({
					prompt = spec.prompt .. ": ",
					default = spec.default,
				}, function(input)
					if input then
						results[key] = input
					else
						results[key] = "" -- 用户取消输入，设为空字符串
					end
					collect_input(index + 1)
				end)
			end

			-- 开始收集输入
			collect_input(1)
		end
	end)
end
return M
