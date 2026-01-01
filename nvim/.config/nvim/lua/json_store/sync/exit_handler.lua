-- json_store/sync/exit_handler.lua
local M = {}

local _pending_exit = false
local _exit_data = {
	buffers = {}, -- { bufnr = { old_lines, timestamp } }
	projects = {}, -- 需要刷新的项目
	timer = nil, -- 退出计时器
}

-- 标记即将退出
function M.prepare_exit()
	if _pending_exit then
		return
	end

	_pending_exit = true

	-- 立即停止所有未完成的diff计时器
	local tracker = require("json_store.sync.tracker")
	tracker.stop_all_timers()

	-- 捕获所有buffer的当前状态
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			if filepath ~= "" then
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				_exit_data.buffers[bufnr] = {
					lines = lines,
					filepath = filepath,
					timestamp = os.time(),
				}
			end
		end
	end

	return true
end

-- 处理单个buffer的退出同步
function M.sync_buffer_on_exit(bufnr)
	if not _exit_data.buffers[bufnr] then
		return
	end

	local data = _exit_data.buffers[bufnr]
	local filepath = data.filepath

	-- 检查文件是否已经保存到磁盘
	local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- 如果文件内容已经保存，直接应用重定位
	if vim.deep_equal(data.lines, current_lines) then
		-- 文件已保存，应用重定位
		local relocator = require("json_store.sync.relocator")
		local project = require("json_store.core.project")

		local _, project_obj = project.get_current_project()
		if project_obj then
			-- 标记项目需要刷新
			_exit_data.projects[project_obj.key] = project_obj
		end
	else
		-- 文件未保存，但我们要退出，强制应用当前状态
		local tracker = require("json_store.sync.tracker")
		tracker.capture_before(bufnr)
		tracker.apply_after(bufnr, true) -- force模式
	end

	-- 清理buffer数据
	_exit_data.buffers[bufnr] = nil
end

-- 同步所有buffer
function M.sync_all_buffers_on_exit()
	for bufnr, _ in pairs(_exit_data.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			M.sync_buffer_on_exit(bufnr)
		end
	end
end

-- 刷新所有项目
function M.flush_all_projects_on_exit()
	local project = require("json_store.core.project")
	local store = require("json_store.core.store")

	-- 刷新内存中的所有项目
	for _, project_obj in pairs(_exit_data.projects) do
		project.flush_project(project_obj)
	end

	-- 额外确保所有项目都被刷新
	project.flush_all_projects()
end

-- 清理资源
function M.cleanup_on_exit()
	-- 清理计时器
	if _exit_data.timer then
		_exit_data.timer:stop()
		_exit_data.timer:close()
		_exit_data.timer = nil
	end

	-- 清理数据
	_exit_data.buffers = {}
	_exit_data.projects = {}
	_pending_exit = false
end

-- 主退出处理函数
function M.handle_exit()
	M.prepare_exit()
	M.sync_all_buffers_on_exit()
	M.flush_all_projects_on_exit()
	M.cleanup_on_exit()
end

return M
