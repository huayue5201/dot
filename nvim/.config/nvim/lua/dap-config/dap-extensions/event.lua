local M = {}
M.listeners = {}

function M.on(name, fn)
	M.listeners[name] = M.listeners[name] or {}
	table.insert(M.listeners[name], fn)
end

function M.emit(name, ...)
	local list = M.listeners[name]
	if not list then
		return
	end
	for _, fn in ipairs(list) do
		pcall(fn, ...)
	end
end

return M
