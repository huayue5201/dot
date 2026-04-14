local M = {}

-- 获取当前线程ID
local function get_current_thread_id(session, event)
	-- 优先使用事件中的线程ID
	if event and event.threadId then
		return event.threadId
	end

	-- 降级方案：获取所有线程，返回第一个或主线程
	if session then
		return M.get_main_thread_id(session)
	end

	return nil
end

-- 获取主线程ID
function M.get_main_thread_id(session)
	if not session then
		return nil
	end

	local ok, resp = pcall(function()
		return session:request_sync("threads", {})
	end)

	if ok and resp and resp.threads and #resp.threads > 0 then
		-- 优先返回主线程（通常第一个或 name 包含 "main"）
		for _, thread in ipairs(resp.threads) do
			if thread.name and string.lower(thread.name):match("main") then
				return thread.id
			end
		end
		-- 没有找到主线程，返回第一个
		return resp.threads[1].id
	end

	return nil
end

-- 获取所有线程
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

-- 获取指定线程的当前栈帧
function M.get_frame_for_thread(session, threadId, frameLevel)
	if not session or not threadId then
		return nil
	end

	frameLevel = frameLevel or 0 -- 0 = 当前帧

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

-- 获取当前停止点的帧（用于数据断点）
-- 需要传入 session 和 event 对象
function M.get_current_frame(session, event)
	if not session then
		return nil
	end

	-- 从事件中获取线程ID
	local threadId = get_current_thread_id(session, event)
	if not threadId then
		return nil
	end

	return M.get_frame_for_thread(session, threadId)
end

-- 兼容旧接口
function M.get_frame(session, event)
	local frame = M.get_current_frame(session, event)
	return frame and frame.id or nil
end

return M
