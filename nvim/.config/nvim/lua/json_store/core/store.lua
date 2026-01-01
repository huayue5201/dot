-- json_store/core/store.lua
local M = {}

function M.load(store)
	if store.data ~= nil then
		local stat = vim.loop.fs_stat(store.path)
		local mtime = stat and stat.mtime and stat.mtime.sec or nil
		if mtime and store.mtime and mtime == store.mtime then
			return store.data
		end
	end

	if vim.fn.filereadable(store.path) == 0 then
		store.data = {}
		store.mtime = nil
		return store.data
	end

	local ok, content = pcall(vim.fn.readfile, store.path)
	if not ok then
		store.data = {}
		return store.data
	end

	local json = table.concat(content, "\n")
	local ok2, decoded = pcall(vim.json.decode, json)
	store.data = ok2 and decoded or {}
	local stat = vim.loop.fs_stat(store.path)
	store.mtime = stat and stat.mtime and stat.mtime.sec or nil

	return store.data
end

function M.write(store)
	if not store.data then
		return
	end

	local ok, json = pcall(vim.json.encode, store.data, { indent = "  ", sort_keys = true })
	if not ok then
		return
	end

	pcall(vim.fn.writefile, vim.split(json, "\n"), store.path)
	store.dirty = false
	local stat = vim.loop.fs_stat(store.path)
	store.mtime = stat and stat.mtime and stat.mtime.sec or nil
end

function M.mark_dirty(store)
	store.dirty = true

	local cfg = require("json_store.core.config").get()
	if not cfg.auto_save then
		return
	end

	if store.timer then
		store.timer:stop()
		store.timer:close()
	end

	local timer = vim.loop.new_timer()
	store.timer = timer

	timer:start(cfg.save_delay_ms, 0, function()
		vim.schedule(function()
			M.write(store)
		end)
		timer:stop()
		timer:close()
		store.timer = nil
	end)
end

return M
