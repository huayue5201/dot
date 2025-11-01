local overseer = require("overseer")

return {
	name = "uv add / pip install",
	builder = function(params)
		local pkg = params.pkg or vim.fn.input("输入包名: ")
		local manager = params.manager or "auto" -- 自动模式

		if not pkg or pkg == "" then
			vim.notify("未输入包名，任务取消", vim.log.levels.WARN)
			return nil
		end

		-- 自动选择管理器
		if manager == "auto" then
			if pkg:match("%.py$") then
				manager = "pip"
			else
				manager = "uv"
			end
		end

		-- 构建命令
		local cmd
		if manager == "uv" then
			cmd = { "uv", "add", pkg }
		elseif manager == "pip" then
			-- uv pip add 已废弃，用 install
			cmd = { "uv", "pip", "install", pkg }
		else
			vim.notify("未知 manager: " .. manager, vim.log.levels.WARN)
			return nil
		end

		return {
			cmd = cmd,
			name = manager .. " install " .. pkg,
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
			name = "管理器 (uv / pip / auto)",
			default = "auto",
		},
	},
	tags = { overseer.TAG.RUN },
	condition = { filetype = { "python" } },
}
