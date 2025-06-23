local M = {}

-- 动画帧序列
M.frames = { "◐", "◓", "◑", "◒" }
-- 当前帧索引
M.current_frame = 1
-- 动画定时器
M.animation_timer = nil
-- 动画开始时间
M.start_time = nil
-- 最小持续时间
M.min_duration = 0
-- 动画是否激活
M.is_active = false
-- 停止请求队列
M.stop_queue = {}

-- 安全刷新状态栏
local function safe_redraw()
	-- 使用 schedule 确保在主线程执行
	vim.schedule(function()
		-- 使用 API 调用替代 vim.cmd
		vim.api.nvim_exec_autocmds("User", { pattern = "SpinnerUpdate" })
	end)
end

-- 启动旋转动画（可选最小持续时间）
function M.start(min_duration)
	if M.is_active then
		M.min_duration = math.max(M.min_duration, min_duration or 0)
		return
	end

	M.is_active = true
	M.current_frame = 1
	M.start_time = vim.loop.now()
	M.min_duration = min_duration or 0

	-- 创建动画定时器
	M.animation_timer = vim.loop.new_timer()
	M.animation_timer:start(
		0,
		100,
		vim.schedule_wrap(function()
			-- 更新帧
			M.current_frame = (M.current_frame % #M.frames) + 1

			-- 安全刷新状态栏
			safe_redraw()
		end)
	)
end

-- 停止旋转动画（可选立即停止）
function M.stop(immediate)
	if not M.is_active then
		return
	end

	-- 计算已运行时间
	local elapsed = vim.loop.now() - M.start_time

	-- 如果未达到最小持续时间且不要求立即停止
	if not immediate and elapsed < M.min_duration then
		-- 计算剩余时间并加入停止队列
		local remaining = M.min_duration - elapsed
		local stop_timer = vim.loop.new_timer()
		table.insert(M.stop_queue, stop_timer)

		stop_timer:start(
			remaining,
			0,
			vim.schedule_wrap(function()
				stop_timer:close()
				M._real_stop()
			end)
		)
		return
	end

	-- 立即停止
	M._real_stop()
end

-- 实际停止动画的内部方法
function M._real_stop()
	-- 清理所有待处理的停止定时器
	for _, timer in ipairs(M.stop_queue) do
		if timer:is_active() then
			timer:stop()
			timer:close()
		end
	end
	M.stop_queue = {}

	-- 停止动画定时器
	if M.animation_timer then
		M.animation_timer:stop()
		M.animation_timer:close()
		M.animation_timer = nil
	end

	-- 更新状态
	M.is_active = false
	M.min_duration = 0

	-- 安全刷新状态栏
	safe_redraw()
end

-- 获取当前帧（可选指定最小持续时间）
function M.get_frame(min_duration)
	if min_duration and min_duration > 0 and not M.is_active then
		M.start(min_duration)
	end
	return M.is_active and M.frames[M.current_frame] or ""
end

-- 清理资源
function M.cleanup()
	M._real_stop()
end

-- 自动清理
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = M.cleanup,
})

return M
