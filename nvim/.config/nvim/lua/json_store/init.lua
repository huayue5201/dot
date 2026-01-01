-- lua/json_store/init.lua
local config = require("json_store.core.config")
local autocmds = require("json_store.maintenance.autocmds")

local M = {}

-- 内部状态
local _initialized = false
local _api_modules = {}

-- 默认配置（优化版）
local default_opts = {
	root_markers = { ".git", "Cargo.toml", "pyproject.toml", "go.mod" },
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v6/",
	auto_save = true,
	save_delay_ms = 1500,
	global_namespaces = { "todo_links", "code_links", "marks" },

	-- 性能优化选项
	auto_sync = true,
	sync_delay_ms = 300, -- 更短的延迟，提高响应性
	max_file_lines = 10000,
	skip_large_files = false, -- 默认不跳过，确保数据完整性

	-- 自动命令选项（推荐配置）
	sync_on_write = true,
	sync_on_insert_leave = true,
	sync_on_cursor_hold = false,
	sync_on_text_changed = false,
}

-- 确保初始化
local function ensure_initialized()
	if not _initialized then
		config.setup(default_opts)
		autocmds.setup()

		-- 预加载核心模块
		_api_modules.ns = require("json_store.data.namespace")
		_api_modules.line = require("json_store.data.line")
		_api_modules.file = require("json_store.data.file")
		_api_modules.project = require("json_store.core.project")
		_api_modules.store = require("json_store.core.store")

		_initialized = true
	end
end

-- 用户配置接口
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

-- API（保持兼容）
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

-- 强制保存所有数据（用于调试）
function M.force_save()
	ensure_initialized()

	local tracker = require("json_store.sync.tracker")
	tracker.force_sync_all()

	local project = require("json_store.core.project")
	project.flush_all_projects()

	vim.notify("json_store: 强制保存完成", vim.log.levels.INFO)
end

-- 状态检查
function M.status()
	ensure_initialized()

	local tracker = require("json_store.sync.tracker")
	local exit_handler = require("json_store.sync.exit_handler")

	return {
		initialized = _initialized,
		config = config.get(),
		tracker_state = {
			pending_buffers = #vim.tbl_keys(tracker._old_buffers or {}),
			changed_buffers = #vim.tbl_keys(tracker._changed_buffers or {}),
		},
		exit_ready = exit_handler._pending_exit or false,
	}
end

-- 延迟初始化
vim.defer_fn(function()
	if not _initialized then
		ensure_initialized()
		vim.notify("json_store: 自动初始化完成", vim.log.levels.INFO)
	end
end, 1000)

return M
