local dap = require("dap")
local popup = require("dap-config.breakpoint_popup")

local M = {}

local function sync_after_set()
	vim.defer_fn(function()
		require("dap-config.breakpoint_state").sync_breakpoints()
	end, 10)
end

function M.set_function_breakpoint()
	popup.open({
		fields = {
			{ key = "func", label = "函数名(必填)" },
			{ key = "condition", label = "条件(可选)" },
			{ key = "hit", label = "命中次数(可选)" },
		},

		on_submit = function(values)
			local func = values.func
			if func == "" then
				vim.notify("⚠️ 函数名不能为空！", vim.log.levels.ERROR)
				return
			end

			local condition = values.condition ~= "" and values.condition or nil
			local hit = values.hit ~= "" and tonumber(values.hit) or nil

			if values.hit ~= "" and not tonumber(values.hit) then
				vim.notify("⚠️ 命中次数必须为数字！", vim.log.levels.ERROR)
				return
			end

			-- ⭐ 函数断点 API：dap.set_breakpoint(func, condition, hit)
			dap.set_breakpoint(func, condition, hit)

			print(
				("✔️ 函数断点已设置：函数=%s 条件=%s 次数=%s"):format(
					func,
					condition or "无",
					hit or "无"
				)
			)

			sync_after_set()
		end,
	})
end

return M
