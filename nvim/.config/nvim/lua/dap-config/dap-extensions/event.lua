-- dap-config/dap-extensions/event.lua
local M = {}

-- listeners[name] = { { fn = function, once = boolean }, ... }
M.listeners = {}

--- 注册事件监听
--- @param name string 事件名
--- @param fn function 回调函数
function M.on(name, fn)
	M.listeners[name] = M.listeners[name] or {}
	table.insert(M.listeners[name], { fn = fn, once = false })
end

--- 注册一次性事件监听（触发一次后自动移除）
--- @param name string
--- @param fn function
function M.once(name, fn)
	M.listeners[name] = M.listeners[name] or {}
	table.insert(M.listeners[name], { fn = fn, once = true })
end

--- 移除事件监听
--- @param name string
--- @param fn function
function M.off(name, fn)
	local list = M.listeners[name]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i].fn == fn then
			table.remove(list, i)
		end
	end
	if #list == 0 then
		M.listeners[name] = nil
	end
end

--- 触发事件
--- @param name string
--- @param ... any
function M.emit(name, ...)
	local list = M.listeners[name]
	if not list or #list == 0 then
		return
	end

	-- 拷贝一份，避免回调里修改 listeners 影响当前遍历
	local snapshot = {}
	for i, item in ipairs(list) do
		snapshot[i] = item
	end

	for _, item in ipairs(snapshot) do
		local ok, err = pcall(item.fn, ...)
		if not ok then
			vim.schedule(function()
				vim.notify(string.format("[dap-ext] event '%s' handler error: %s", name, err), vim.log.levels.WARN)
			end)
		end
		if item.once then
			M.off(name, item.fn)
		end
	end
end

return M
