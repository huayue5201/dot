-- dap-config/dap-extensions/resolver.lua
local M = {}

--- 获取主线程 ID
--- @param session table
--- @return integer|nil
function M.get_main_thread_id(session)
	if not session then
		return nil
	end

	local ok, resp = pcall(function()
		return session:request_sync("threads", {})
	end)

	if not ok or not resp or not resp.threads or #resp.threads == 0 then
		return nil
	end

	-- 优先 name 包含 main 的线程
	for _, thread in ipairs(resp.threads) do
		if thread.name and string.lower(thread.name):match("main") then
			return thread.id
		end
	end

	-- 否则返回第一个
	return resp.threads[1].id
end

--- 获取所有线程
--- @param session table
--- @return table
function M.get_all_threads(session)
	if not session then
		return {}
	end

	local ok, resp = pcall(function()
		return session:request_sync("threads", {})
	end)

	if ok and resp and resp.threads then
		return resp.threads
	end

	return {}
end

--- 获取指定线程的当前栈帧
--- @param session table
--- @param threadId integer
--- @param frameLevel? integer
--- @return table|nil
function M.get_frame_for_thread(session, threadId, frameLevel)
	if not session or not threadId then
		return nil
	end

	frameLevel = frameLevel or 0

	local ok, resp = pcall(function()
		return session:request_sync("stackTrace", {
			threadId = threadId,
			levels = 1,
			startFrame = frameLevel,
		})
	end)

	if ok and resp and resp.stackFrames and #resp.stackFrames > 0 then
		return resp.stackFrames[1]
	end

	return nil
end

--- 获取当前停止点的帧（用于数据断点）
--- @param session table
--- @param event table
--- @return table|nil
function M.get_current_frame(session, event)
	if not session then
		return nil
	end

	local threadId = nil
	if event and event.threadId then
		threadId = event.threadId
	end

	if not threadId then
		threadId = M.get_main_thread_id(session)
	end

	if not threadId then
		return nil
	end

	return M.get_frame_for_thread(session, threadId)
end

--- 兼容旧接口：返回 frame id
--- @param session table
--- @param event table
--- @return integer|nil
function M.get_frame(session, event)
	local frame = M.get_current_frame(session, event)
	return frame and frame.id or nil
end

return M
