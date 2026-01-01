-- json_store/sync/tracker.lua
local relocator = require("json_store.sync.relocator")
local config = require("json_store.core.config")

local M = {}

-- 状态存储
local _old_buffers = {} -- 旧内容缓存
local _changed_buffers = {} -- 有未处理变化的buffer
local _line_counts = {} -- 记录行数，用于快速检查
local _dirty_buffers = {} -- 标记为脏（需要保存）的buffer

-- Debounce计时器
local diff_timer = nil
local pending = {} -- { [bufnr] = true }

-- 强制模式标志
local _force_mode = false

---------------------------------------------------------
-- 计时器管理
---------------------------------------------------------
function M.stop_all_timers()
	if diff_timer then
		diff_timer:stop()
		diff_timer:close()
		diff_timer = nil
	end
	pending = {}
end

---------------------------------------------------------
-- 公共API
---------------------------------------------------------
function M.has_changes(bufnr)
	return _changed_buffers[bufnr] == true
end

function M.mark_changed(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	_changed_buffers[bufnr] = true
end

function M.mark_dirty(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	_dirty_buffers[bufnr] = true
end

function M.capture_before(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	_old_buffers[bufnr] = {
		line_count = line_count,
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
		timestamp = os.time(),
	}

	_line_counts[bufnr] = line_count
end

---------------------------------------------------------
-- 优化的diff计算
---------------------------------------------------------
local function compute_hunks(old_data, new_lines)
	local new_line_count = #new_lines
	local old_line_count = old_data.line_count

	-- 如果行数没变，返回空hunks
	if old_line_count == new_line_count then
		return {}
	end

	-- 只在force模式或小变化时使用精确diff
	if _force_mode or math.abs(new_line_count - old_line_count) <= 10 then
		local ok, result = pcall(vim.diff, table.concat(old_data.lines, "\n"), table.concat(new_lines, "\n"), {
			result_type = "indices",
			algorithm = "patience",
		})

		if ok and result then
			local hunks = {}
			for _, h in ipairs(result) do
				table.insert(hunks, { h[1], h[2], h[3], h[4] })
			end
			return hunks
		end
	end

	-- 使用简单hunks
	local hunks = {}
	local delta = new_line_count - old_line_count

	if delta > 0 then
		-- 增加了行
		table.insert(hunks, { old_line_count + 1, 0, old_line_count + 1, delta })
	elseif delta < 0 then
		-- 减少了行
		table.insert(hunks, { old_line_count + delta + 1, -delta, old_line_count + delta + 1, 0 })
	end

	return hunks
end

---------------------------------------------------------
-- 应用diff（核心逻辑）
---------------------------------------------------------
local function apply_diff(bufnr, force)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local old_data = _old_buffers[bufnr]
	if not old_data and not force then
		return
	end

	local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- 计算hunks
	local hunks = {}
	if old_data then
		hunks = compute_hunks(old_data, new_lines)
	end

	-- 应用重定位（即使hunks为空，也允许重定位检查）
	relocator.relocate(bufnr, hunks)

	-- 清理（除非是force模式）
	if not force then
		_old_buffers[bufnr] = nil
		_changed_buffers[bufnr] = false
		_line_counts[bufnr] = nil
		_dirty_buffers[bufnr] = nil
	end
end

---------------------------------------------------------
-- 调度和定时器
---------------------------------------------------------
function M.schedule_diff(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	pending[bufnr] = true

	-- 创建或重启计时器
	if not diff_timer then
		diff_timer = vim.loop.new_timer()
	end

	local cfg = config.get()

	diff_timer:stop()
	diff_timer:start(
		cfg.sync_delay_ms,
		0,
		vim.schedule_wrap(function()
			for buf, _ in pairs(pending) do
				if vim.api.nvim_buf_is_valid(buf) then
					apply_diff(buf)
				end
			end
			pending = {}

			if diff_timer then
				diff_timer:close()
				diff_timer = nil
			end
		end)
	)
end

---------------------------------------------------------
-- 立即应用diff（支持force模式）
---------------------------------------------------------
function M.apply_after(bufnr, force)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- 设置force模式
	_force_mode = force or false

	-- 清除pending状态
	pending[bufnr] = nil

	-- 停止计时器
	if diff_timer then
		diff_timer:stop()
	end

	-- 立即应用
	apply_diff(bufnr, force)

	-- 重置force模式
	_force_mode = false
end

---------------------------------------------------------
-- 强制同步所有buffer（用于退出）
---------------------------------------------------------
function M.force_sync_all()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			if filepath ~= "" and (_old_buffers[bufnr] or _dirty_buffers[bufnr]) then
				M.apply_after(bufnr, true)
			end
		end
	end
end

return M
