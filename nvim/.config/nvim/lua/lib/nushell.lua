-- lua/lib/nushell.lua
---@brief 代码运行（runnables）专用的 nushell 包装
-- 只给「跑代码」用：cargo run / go test / 当前文件执行这类需要看输出的场景。
-- 构建、烧录、任务面板一律不动，直接用原始 argv 执行。
--
-- 为什么要包一层：nvim 的 termopen({...}) 直接 execvp，argv 原样传给程序，
-- 拿不到 nushell 的输出处理能力（`| lines`、`from json`、表格渲染等）。
-- 这里把 argv 转义后交给 `nu --no-config-file -c 'run-external ...'`，
-- 需要额外管道时设置 vim.g.nushell_code_pipeline（例如 "| lines"）。

local M = {}

---nu 是否可用
---@return boolean
function M.available()
	if vim.g.nushell_code_run == false then
		return false
	end
	return vim.fn.executable("nu") == 1
end

-- nu 字符串转义：单引号是字面量，双引号里需要处理 \ " $（$ 会触发插值）
---@param s string
---@return string
local function quote(s)
	if s == "" then
		return "''"
	end
	if s:match("^[%w%-%._/:=@%%%+,]+$") then
		return s
	end
	if not s:find("'") then
		return "'" .. s .. "'"
	end
	local escaped = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("%$", "\\$")
	return '"' .. escaped .. '"'
end

---把 argv 包成 nushell 命令行：run-external 按值接收参数，不受 nu 内置命令名影响
---@param cmd string[]
---@return string
function M.command_line(cmd)
	local parts = {}
	for i, v in ipairs(cmd) do
		parts[i] = quote(v)
	end
	local line = "run-external -- " .. table.concat(parts, " ")
	local pipeline = vim.g.nushell_code_pipeline
	if type(pipeline) == "string" and pipeline ~= "" then
		line = line .. " " .. pipeline
	end
	return line
end

---@param cmd string[]
---@return string[]
local function wrap(cmd)
	return { "nu", "--no-config-file", "-c", M.command_line(cmd) }
end

---在终端里跑命令（带 nushell 包装；nu 不可用时回退到原始 argv）
---@param cmd string[]
---@param opts? table termopen 选项（cwd/env）
---@return integer buf
function M.run(cmd, opts)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].bufhidden = "wipe"
	vim.fn.termopen(M.available() and wrap(cmd) or cmd, (opts and next(opts)) and opts or vim.empty_dict())
	vim.cmd.startinsert()
	return buf
end

return M
