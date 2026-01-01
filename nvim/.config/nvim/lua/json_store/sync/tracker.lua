-- json_store/sync/tracker.lua (v6.4 + v6.5 + v6.6)
local config = require("json_store.core.config")
local project = require("json_store.core.project")
local file = require("json_store.data.file")
local store = require("json_store.core.store")

local relocator = require("json_store.sync.relocator")
local anchor = require("json_store.data.anchor")

local M = {}

-- 旧内容缓存：bufnr -> { lines = {...}, changedtick = N }
local _old_buffers = {}
local _timers = {}

-- diff 缓存：bufnr -> { changedtick = N, result = { [old_line] = new_line or false } }
local _diff_cache = {}

M._old_buffers = _old_buffers
M._diff_cache = _diff_cache

---------------------------------------------------------
-- 1. 捕获旧内容（在 TextChanged / BufWritePost 前）
---------------------------------------------------------
function M.capture_before(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)

	_old_buffers[bufnr] = {
		lines = lines,
		changedtick = tick,
	}
end

---------------------------------------------------------
-- 2. 获取局部 diff 范围（v6.3 核心）
---------------------------------------------------------
local function get_changed_range(bufnr)
	local start = vim.fn.getpos("'<")[2]
	local finish = vim.fn.getpos("'>")[2]

	if start == 0 or finish == 0 then
		return nil
	end

	if start > finish then
		start, finish = finish, start
	end

	return start, finish
end

---------------------------------------------------------
-- 3. 计算局部 diff 范围（扩大 50 行）
---------------------------------------------------------
local function compute_partial_range(bufnr, start, finish)
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	local diff_start = math.max(1, start - 50)
	local diff_end = math.min(line_count, finish + 50)

	return diff_start, diff_end
end

---------------------------------------------------------
-- 4. diff 缓存：获取 / 写入
---------------------------------------------------------
local function get_cached_diff(bufnr, tick)
	local cache = _diff_cache[bufnr]
	if not cache then
		return nil
	end
	if cache.changedtick ~= tick then
		return nil
	end
	return cache.result
end

local function set_cached_diff(bufnr, tick, result)
	_diff_cache[bufnr] = {
		changedtick = tick,
		result = result,
	}
end

---------------------------------------------------------
-- 5. 增量 anchor 更新（只更新受影响行）
---------------------------------------------------------
local function update_anchors_incremental(bufnr, file_data, diff_start, diff_end)
	if not file_data.lines then
		return
	end

	for line_str, entry in pairs(file_data.lines) do
		local lnum = tonumber(line_str)
		if lnum and lnum >= diff_start and lnum <= diff_end then
			-- 只为受影响行重新生成 anchor
			entry.anchor = anchor.create_anchor(bufnr, lnum)
		end
	end
end

---------------------------------------------------------
-- 6. 同步 diff（核心逻辑，可在主线程或 worker 中调用）
---------------------------------------------------------
local function do_apply_diff(bufnr, old, new_lines, filepath)
	local _, project_obj = project.get_current_project()
	local store_obj = file.get_file_store(project_obj, filepath)
	local file_data = store.load(store_obj)

	if not file_data.lines then
		return
	end

	local tick = old.changedtick or vim.api.nvim_buf_get_changedtick(bufnr)

	-- 先尝试使用缓存 diff 结果
	local cached = get_cached_diff(bufnr, tick)
	local diff_result = cached or {}

	local start, finish = get_changed_range(bufnr)
	local partial_ok = false
	local diff_start, diff_end

	if start then
		diff_start, diff_end = compute_partial_range(bufnr, start, finish)
	end

	local updated = {}

	for line_str, entry in pairs(file_data.lines or {}) do
		local old_line = tonumber(line_str)
		local new_line = nil

		-- 优先使用缓存
		if diff_result[old_line] ~= nil then
			new_line = diff_result[old_line]
		else
			-- 如果有局部范围，只对范围内行做 relocate
			if diff_start and diff_end and old_line >= diff_start and old_line <= diff_end then
				new_line = relocator.relocate(bufnr, old_line, entry.anchor)
				partial_ok = true
			else
				-- 范围外的行认为未变动，保持原位
				new_line = old_line
			end
			diff_result[old_line] = new_line or false
		end

		if new_line and new_line >= 1 and new_line <= #new_lines then
			updated[tostring(new_line)] = {
				data = entry.data,
				anchor = entry.anchor,
			}
		end
	end

	-- 如果局部 diff 完全没起作用（比如整文件重写），fallback：全量 relocate
	if not partial_ok then
		updated = {}
		diff_result = {}

		for line_str, entry in pairs(file_data.lines or {}) do
			local old_line = tonumber(line_str)
			local new_line = relocator.relocate(bufnr, old_line, entry.anchor)
			diff_result[old_line] = new_line or false

			if new_line and new_line >= 1 and new_line <= #new_lines then
				updated[tostring(new_line)] = {
					data = entry.data,
					anchor = entry.anchor,
				}
			end
		end
	end

	-- 写回
	file_data.lines = updated

	-- 增量更新 anchor（只更新受影响区域）
	if diff_start and diff_end then
		update_anchors_incremental(bufnr, file_data, diff_start, diff_end)
	end

	-- 缓存 diff 结果
	set_cached_diff(bufnr, tick, diff_result)

	store.mark_dirty(store_obj)
end

---------------------------------------------------------
-- 7. apply_after：支持异步 diff（v6.6）
---------------------------------------------------------
function M.apply_after(bufnr)
	local old = _old_buffers[bufnr]
	if not old then
		return
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		_old_buffers[bufnr] = nil
		return
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		_old_buffers[bufnr] = nil
		return
	end

	local new_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- 异步执行 diff（下一帧执行，不阻塞 UI）
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			do_apply_diff(bufnr, old, new_lines, filepath)
		end
	end)

	_old_buffers[bufnr] = nil
end

---------------------------------------------------------
-- 8. debounce diff（保持 v6.2 / v6.3 逻辑）
---------------------------------------------------------
function M.schedule_diff(bufnr)
	local cfg = config.get()
	local delay = cfg.sync_delay_ms or 300

	if _timers[bufnr] then
		_timers[bufnr]:stop()
		_timers[bufnr]:close()
		_timers[bufnr] = nil
	end

	local timer = vim.loop.new_timer()
	_timers[bufnr] = timer

	timer:start(delay, 0, function()
		vim.schedule(function()
			M.apply_after(bufnr)
		end)
		timer:stop()
		timer:close()
		_timers[bufnr] = nil
	end)
end

---------------------------------------------------------
-- 9. 退出前强制同步所有 buffer
---------------------------------------------------------
function M.force_sync_all()
	for bufnr, _ in pairs(_old_buffers) do
		M.apply_after(bufnr)
	end
end

return M
