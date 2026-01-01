-- lua/json_store/init.lua
local config = require("json_store.core.config")
local autocmds = require("json_store.maintenance.autocmds")

local M = {}

local _initialized = false
local _api_modules = {}

local default_opts = {
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v6/",
	auto_save = true,
	save_delay_ms = 1500,
	global_namespaces = { "todo_links", "code_links", "marks" },
	sync_delay_ms = 300,
}

local function ensure_initialized()
	if _initialized then
		return
	end

	config.setup(default_opts)
	autocmds.setup()

	_api_modules.ns = require("json_store.data.namespace")
	_api_modules.line = require("json_store.data.line")
	_api_modules.file = require("json_store.data.file")
	_api_modules.project = require("json_store.core.project")
	_api_modules.store = require("json_store.core.store")

	_initialized = true
end

function M.setup(opts)
	config.setup(vim.tbl_deep_extend("force", default_opts, opts or {}))
	autocmds.setup()

	_api_modules.ns = require("json_store.data.namespace")
	_api_modules.line = require("json_store.data.line")
	_api_modules.file = require("json_store.data.file")
	_api_modules.project = require("json_store.core.project")
	_api_modules.store = require("json_store.core.store")

	_initialized = true
	return M
end

function M.set(namespace, key, value, file_id, use_global)
	ensure_initialized()
	return _api_modules.ns.set(namespace, key, value, file_id, use_global)
end

function M.get(namespace, key, file_id, use_global)
	ensure_initialized()
	return _api_modules.ns.get(namespace, key, file_id, use_global)
end

function M.delete(namespace, key, file_id, use_global)
	ensure_initialized()
	return _api_modules.ns.delete(namespace, key, file_id, use_global)
end

function M.get_all(namespace, use_global)
	ensure_initialized()
	return _api_modules.ns.get_all(namespace, use_global)
end

function M.set_line_data(filepath, line, data)
	ensure_initialized()
	return _api_modules.line.set_line_data(filepath, line, data)
end

function M.get_line_data(filepath, line)
	ensure_initialized()
	return _api_modules.line.get_line_data(filepath, line)
end

function M.get_current_project()
	ensure_initialized()
	return _api_modules.project.get_current_project()
end

function M.force_save()
	ensure_initialized()

	local tracker = require("json_store.sync.tracker")
	tracker.force_sync_all()

	local project = require("json_store.core.project")
	project.flush_all_projects()

	vim.notify("json_store: 强制保存完成", vim.log.levels.INFO)
end

function M.status()
	ensure_initialized()

	local tracker = require("json_store.sync.tracker")

	return {
		initialized = _initialized,
		config = config.get(),
		tracker_state = {
			pending_buffers = #vim.tbl_keys(tracker._old_buffers or {}),
		},
	}
end

return M
