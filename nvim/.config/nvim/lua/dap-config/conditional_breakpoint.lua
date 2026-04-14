local dap = require("dap")
local popup = require("dap-config.dap-extensions.ui.popup")

local M = {}

local function sync_after_set()
	vim.defer_fn(function()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, 10)
end

function M.set_breakpoint()
	popup.open({
		fields = {
			{ key = "condition", label = "条件(可选)" },
			{ key = "hit", label = "命中次数(可选)" },
			{ key = "log", label = "日志消息(可选)" },
		},

		on_submit = function(values)
			local condition = values.condition ~= "" and values.condition or nil
			local hit = values.hit ~= "" and tonumber(values.hit) or nil
			local log = values.log ~= "" and values.log or nil

			if values.hit ~= "" and not tonumber(values.hit) then
				vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
				return
			end

			dap.toggle_breakpoint(condition, hit, log)

			print(
				("✔️ 断点已设置：条件=%s 次数=%s 日志=%s"):format(
					condition or "无",
					hit or "无",
					log or "无"
				)
			)

			sync_after_set()
		end,
	})
end

return M
