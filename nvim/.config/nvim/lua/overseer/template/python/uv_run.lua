local overseer = require("overseer")

-- 递归搜索 main.py
local function find_main_py()
	local handle = io.popen("fd main.py --type f 2>/dev/null")
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	local path = result:match("([^\n]+)")
	return path
end

return {
	name = "uv run",
	-- desc = "Run Python script using `uv run main.py` (auto-detects main.py, supports args)",
	builder = function(params)
		local main_path = find_main_py() or "main.py"

		local args = { "run", main_path }

		if params.args and params.args ~= "" then
			vim.list_extend(args, vim.split(params.args, "%s+"))
		end

		return {
			cmd = { "uv" },
			args = args,
			name = "uv run " .. main_path,
			cwd = vim.fn.getcwd(),
			components = {
				"default",
				"on_output_summarize",
				"on_exit_set_status",
				{ "open_output", direction = "horizontal", focus = true }, -- ✅ 新版终端输出组件
			},
			env = {
				PYTHONUNBUFFERED = "1",
			},
		}
	end,

	params = {
		args = {
			desc = "Arguments to pass to main.py",
			type = "string",
			optional = true,
		},
	},

	tags = { overseer.TAG.RUN },
	condition = {
		filetype = { "python" },
		callback = function()
			return find_main_py() ~= nil
		end,
	},
}
