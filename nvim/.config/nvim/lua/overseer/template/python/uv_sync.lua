local overseer = require("overseer")

return {
	name = "uv sync",
	desc = "Synchronize dependencies using `uv sync` (resolves and installs project dependencies)",
	builder = function(params)
		-- 构建命令参数
		local args = { "sync" }

		if params.args and params.args ~= "" then
			vim.list_extend(args, vim.split(params.args, "%s+"))
		end

		return {
			cmd = { "uv" },
			args = args,
			name = "uv sync",
			cwd = vim.fn.getcwd(),
			components = {
				"default",
				"on_output_summarize",
				"on_exit_set_status",
				{ "open_output", direction = "horizontal", focus = true },
			},
			env = {
				UV_NO_CACHE = params.no_cache and "1" or nil,
			},
		}
	end,

	params = {
		args = {
			desc = "Additional arguments for `uv sync` (e.g. --upgrade, --force)",
			type = "string",
			optional = true,
		},
		no_cache = {
			desc = "Disable uv cache during sync",
			type = "boolean",
			optional = true,
			default = false,
		},
	},

	tags = { overseer.TAG.BUILD },
	condition = {
		callback = function()
			-- 判断项目中是否有 uv 配置文件
			return vim.fn.filereadable("pyproject.toml") == 1 or vim.fn.filereadable("uv.lock") == 1
		end,
	},
}
