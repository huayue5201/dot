local M = {}

M.bps = {}
M.map = {} -- 支持 id 或 dataId 到 bp 的映射

function M.add(bp)
	M.bps[bp.id] = bp
end

function M.link(key, bp)
	M.map[tostring(key)] = bp
end

function M.resolve(key)
	if not key then
		return nil
	end
	return M.map[tostring(key)] or M.bps[key]
end

function M.remove(id)
	M.bps[id] = nil
	-- 同时从 map 中删除
	for k, bp in pairs(M.map) do
		if bp.id == id then
			M.map[k] = nil
			break
		end
	end
end

return M
