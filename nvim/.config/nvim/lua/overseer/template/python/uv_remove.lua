local overseer = require("overseer")

return {
	name = "uv remove",
	builder = function(params)
		local pkg = params.pkg or vim.fn.input("输入包名: ")

		if not pkg or pkg == "" then
			vim.notify("未输入包名，任务取消", vim.log.levels.WARN)
			return nil
		end

		return {
			cmd = { "uv", "remove", pkg },
			name = "uv remove " .. pkg,
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
	},
	tags = { overseer.TAG.RUN },
	condition = { filetype = { "python" } },
}
