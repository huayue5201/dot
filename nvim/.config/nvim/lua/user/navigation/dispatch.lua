-- 命令分发器：把 cmd 字符串/函数分发到对应逻辑
local M = {}

local errors = require("user.navigation.errors")
local smart_close = require("user.navigation.smart_close")

-- 支持的命令：next_error, prev_error, next_error_repeatable,
-- prev_error_repeatable, smart_close, 任意函数, 或 vim 命令字符串
---@param cmd string|function
function M.dispatch_command(cmd)
	if cmd == "next_error" then
		errors.next_error()
	elseif cmd == "prev_error" then
		errors.prev_error()
	elseif cmd == "next_error_repeatable" then
		errors.next_error_repeatable()
	elseif cmd == "prev_error_repeatable" then
		errors.prev_error_repeatable()
	elseif cmd == "smart_close" then
		smart_close.smart_close()
	elseif type(cmd) == "function" then
		cmd()
	else
		pcall(vim.cmd, cmd)
	end
end

return M
