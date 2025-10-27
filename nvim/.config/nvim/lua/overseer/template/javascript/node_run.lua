local overseer = require("overseer")

-- ================================
-- 查找主文件
-- 支持 JS/TS 文件
-- ================================
local function find_main_file()
	-- 使用 fd 查找 index.js/main.js/index.ts/main.ts
	local handle = io.popen("fd -e js -e ts 'index.js|main.js|index.ts|main.ts' 2>/dev/null")
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	local path = result:match("([^\n]+)")
	return path
end

-- ================================
-- 构建 Overseer 任务
-- ================================
return {
	name = "js/ts run",

	builder = function(params)
		-- 查找主文件
		local main_path = find_main_file()

		-- 如果没找到，使用当前 buffer 文件
		if not main_path or main_path == "" then
			main_path = vim.fn.expand("%:p")
		end

		-- 根据扩展名选择运行命令
		local ext = vim.fn.fnamemodify(main_path, ":e")
		local cmd = ""
		if ext == "js" or ext == "jsx" then
			cmd = "node"
		elseif ext == "ts" or ext == "tsx" then
			cmd = "ts-node"
		else
			-- 其他文件类型也用 node 尝试运行
			cmd = "node"
		end

		-- 构建参数列表
		local args = { main_path }
		if params.args and params.args ~= "" then
			vim.list_extend(args, vim.split(params.args, "%s+"))
		end

		-- 返回 Overseer 任务配置
		return {
			cmd = { cmd },
			args = args,
			name = "run " .. vim.fn.fnamemodify(main_path, ":t"), -- 显示文件名
			cwd = vim.fn.getcwd(),
			components = {
				"default",
				"on_output_summarize",
				"on_exit_set_status",
				{ "open_output", direction = "horizontal", focus = true },
			},
			env = {
				NODE_ENV = "development",
			},
		}
	end,

	params = {
		args = {
			desc = "Arguments to pass to the JS/TS file",
			type = "string",
			optional = true,
		},
	},

	tags = { overseer.TAG.RUN },

	condition = {
		filetype = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		callback = function()
			-- 当前 buffer 必须是有效文件
			return vim.fn.expand("%:p") ~= ""
		end,
	},
}
