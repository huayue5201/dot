-- json_store/maintenance/autocmds.lua
local config = require("json_store.core.config")
local cleanup = require("json_store.maintenance.cleanup")
local project = require("json_store.core.project")
local tracker = require("json_store.sync.tracker")
local exit_handler = require("json_store.sync.exit_handler")

local M = {}

-- 初始化标志
local _autocmd_group_set = false

-- 检查是否应该处理buffer
local function should_process_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return false
	end

	local cfg = config.get()

	-- 跳过大文件
	if cfg.skip_large_files then
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		if line_count > cfg.max_file_lines then
			return false
		end
	end

	return true
end

function M.setup()
	if _autocmd_group_set then
		return
	end

	local cfg = config.get()

	-- 主自动命令组
	local main_group = vim.api.nvim_create_augroup("JsonStoreV6", { clear = true })

	----------------------------------------------------------------------
	-- 1. BufWritePre：捕获旧内容
	----------------------------------------------------------------------
	if cfg.sync_on_write then
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = main_group,
			callback = function(args)
				if should_process_buffer(args.buf) then
					tracker.capture_before(args.buf)
					tracker.mark_dirty(args.buf)
				end
			end,
		})
	end

	----------------------------------------------------------------------
	-- 2. BufWritePost：写入后立即同步
	----------------------------------------------------------------------
	if cfg.sync_on_write then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = main_group,
			callback = function(args)
				if should_process_buffer(args.buf) then
					tracker.apply_after(args.buf)
				end
			end,
		})
	end

	----------------------------------------------------------------------
	-- 3. InsertLeave：插入模式结束时触发
	----------------------------------------------------------------------
	if cfg.sync_on_insert_leave then
		vim.api.nvim_create_autocmd("InsertLeave", {
			group = main_group,
			callback = function(args)
				if should_process_buffer(args.buf) then
					tracker.capture_before(args.buf)
					tracker.schedule_diff(args.buf)
				end
			end,
		})
	end

	----------------------------------------------------------------------
	-- 4. CursorHold：用户暂停时触发
	----------------------------------------------------------------------
	if cfg.sync_on_cursor_hold then
		vim.api.nvim_create_autocmd("CursorHold", {
			group = main_group,
			callback = function(args)
				if should_process_buffer(args.buf) and tracker.has_changes(args.buf) then
					tracker.capture_before(args.buf)
					tracker.schedule_diff(args.buf)
				end
			end,
		})
	end

	----------------------------------------------------------------------
	-- 5. QuitPre：准备退出（修复ZZ的关键）
	----------------------------------------------------------------------
	vim.api.nvim_create_autocmd("QuitPre", {
		group = main_group,
		callback = function()
			-- 准备退出，但不要立即处理，因为可能还有后续事件
			exit_handler.prepare_exit()
		end,
	})

	----------------------------------------------------------------------
	-- 6. VimLeavePre：最终退出处理（修复ZZ的关键）
	----------------------------------------------------------------------
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = main_group,
		callback = function()
			-- 使用专门的退出处理器
			exit_handler.handle_exit()

			-- 额外确保所有项目都被刷新
			project.flush_all_projects()

			-- 快速清理
			cleanup.cleanup_all_projects({
				limit_per_project = 50,
				skip_recent = 0,
			})
		end,
	})

	----------------------------------------------------------------------
	-- 7. DirChanged：项目切换
	----------------------------------------------------------------------
	vim.api.nvim_create_autocmd("DirChanged", {
		group = main_group,
		callback = function()
			cleanup.cleanup_stale_projects()
			cleanup.smart_cleanup()
		end,
	})

	----------------------------------------------------------------------
	-- 8. BufDelete：清理文件引用
	----------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufDelete", {
		group = main_group,
		callback = function(args)
			local filepath = vim.api.nvim_buf_get_name(args.buf)
			if filepath ~= "" then
				cleanup.cleanup_file_refs(filepath)
			end
		end,
	})

	----------------------------------------------------------------------
	-- 9. BufWinLeave：窗口离开时检查是否需要保存
	----------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWinLeave", {
		group = main_group,
		callback = function(args)
			if should_process_buffer(args.buf) and tracker.has_changes(args.buf) then
				tracker.capture_before(args.buf)
				tracker.schedule_diff(args.buf)
			end
		end,
	})

	_autocmd_group_set = true
end

return M
