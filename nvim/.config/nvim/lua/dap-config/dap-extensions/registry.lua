-- dap-config/dap-extensions/registry.lua
local M = {}

-- bps[id] = bp
M.bps = {}
-- map[key] = bp（key 可以是 dataId / functionName / instruction_reference 等）
M.map = {}

--- 添加断点
--- @param bp table
function M.add(bp)
	if not bp or not bp.id then
		return
	end
	M.bps[bp.id] = bp
end

--- 建立 key -> bp 的映射（例如 dataId / functionName）
--- @param key any
--- @param bp table
function M.link(key, bp)
	if not key or not bp or not bp.id then
		return
	end
	M.map[tostring(key)] = bp
end

--- 解析断点
--- @param key any
--- @return table|nil
function M.resolve(key)
	if not key then
		return nil
	end
	local k = tostring(key)
	return M.map[k] or M.bps[key] or M.bps[k]
end

--- 移除断点
--- @param id any
function M.remove(id)
	if not id then
		return
	end
	local target = M.bps[id] or M.bps[tostring(id)]
	if not target then
		return
	end

	-- 从 bps 删除
	for k, bp in pairs(M.bps) do
		if bp == target then
			M.bps[k] = nil
		end
	end

	-- 从 map 删除所有指向该 bp 的 key
	for k, bp in pairs(M.map) do
		if bp == target then
			M.map[k] = nil
		end
	end
end

--- 清空所有断点
function M.clear()
	M.bps = {}
	M.map = {}
end

return M
