local overseer = require("overseer")

return {
	name = "uv remove / pip uninstall",
	builder = function(params)
		local pkg = params.pkg or vim.fn.input("输入包名: ")
		local manager = params.manager or "uv"

		if not pkg or pkg == "" then
			vim.notify("未输入包名，任务取消", vim.log.levels.WARN)
			return nil
		end

		local cmd
		if manager == "uv" then
			cmd = { "uv", "remove", pkg }
		elseif manager == "pip" then
			-- uv pip remove 已废弃，用 uninstall
			cmd = { "uv", "pip", "uninstall", pkg }
		else
			vim.notify("未知 manager: " .. manager, vim.log.levels.WARN)
			return nil
		end

		return {
			cmd = cmd,
			name = manager .. " remove " .. pkg,
			cwd = vim.fn.getcwd(),
			components = {
				"default",
				"on_output_summarize",
				"on_exit_set_status",
				{ "open_output", direction = "horizontal", focus = true },
			},
		}
	end,
	params = {
		pkg = {
			type = "string",
			optional = false,
			name = "包名",
		},
		manager = {
			type = "string",
			optional = true,
			name = "管理器 (uv / pip)",
			default = "uv",
		},
	},
	tags = { overseer.TAG.RUN },
	condition = { filetype = { "python" } },
}
