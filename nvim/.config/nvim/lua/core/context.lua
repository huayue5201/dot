-- lua/core/context.lua
---@brief 跨模块共享的运行上下文（解耦，例如 DAP 调试状态）
-- 目的：让 LSP 等模块依赖一个中立的状态源，而不是直接读 DAP 的全局变量。
local M = {
	_debug = false,
	_listeners = {},
}

---当前是否处于调试会话中
---@return boolean
function M.is_debug()
	return M._debug
end

---更新调试状态并通知监听者（值未变化时静默）
---@param active boolean
function M.set_debug(active)
	local value = active and true or false
	if M._debug == value then
		return
	end
	M._debug = value
	for _, cb in ipairs(M._listeners) do
		pcall(cb, value)
	end
end

---订阅调试状态变化
---@param cb fun(active: boolean)
function M.on_debug_change(cb)
	table.insert(M._listeners, cb)
end

return M
