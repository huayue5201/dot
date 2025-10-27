local overseer = require("overseer")

return {
	name = "npm install <package>",
	builder = function(params)
		local pkg = params.pkg or vim.fn.input("输入包名: ")

		if not pkg or pkg == "" then
			vim.notify("未输入包名，任务取消", vim.log.levels.WARN)
			return nil
		end

		-- 可以选择用 npm 或 yarn
		local manager = params.manager or "npm" -- 默认 npm
		local cmd = { manager, "install", pkg }

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
			name = "包管理器 (npm/yarn/pnpm)",
		},
	},
	tags = { overseer.TAG.RUN },
	condition = { filetype = { "javascript", "typescript", "javascriptreact", "typescriptreact" } },
}
