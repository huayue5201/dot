-- json_store/maintenance/autocmds.lua
local config = require("json_store.core.config")
local project = require("json_store.core.project")
local tracker = require("json_store.sync.tracker")
local cleanup = require("json_store.maintenance.cleanup")

local M = {}

local _autocmd_group_set = false

local function should_process_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return false
	end

	return true
end

function M.setup()
	if _autocmd_group_set then
		return
	end
	_autocmd_group_set = true

	local cfg = config.get()
	local group = vim.api.nvim_create_augroup("JsonStoreV62", { clear = true })

	-- TextChanged：capture + debounce diff
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(args)
			if not should_process_buffer(args.buf) then
				return
			end
			tracker.capture_before(args.buf)
			tracker.schedule_diff(args.buf)
		end,
	})

	-- BufWritePost：强制立即 diff
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(args)
			if not should_process_buffer(args.buf) then
				return
			end
			tracker.capture_before(args.buf)
			tracker.apply_after(args.buf)
		end,
	})

	-- QuitPre：退出前强制同步 + flush + cleanup
	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function()
			tracker.force_sync_all()
			project.flush_all_projects()
			cleanup.cleanup_all_projects()
		end,
	})
end

return M
