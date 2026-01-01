-- json_store/core/config.lua
local M = {}

M.defaults = {
	root_markers = { ".git", ".hg", ".svn", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" },
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v6/",
	auto_save = true,
	save_delay_ms = 1500,
	cleanup_strategy = "conservative",
	max_cache_age = 7200,
	max_projects = 10,
	global_namespaces = {},

	-- 性能优化选项
	auto_sync = true,
	sync_delay_ms = 500, -- diff debounce延迟
	max_file_lines = 5000, -- 不处理行数过多的文件
	skip_large_files = true,

	-- 自动命令选项
	sync_on_write = true, -- BufWritePost时同步
	sync_on_insert_leave = true, -- InsertLeave时同步
	sync_on_cursor_hold = false, -- CursorHold时同步（较慢）
	sync_on_text_changed = false, -- TextChanged时同步（不推荐）

	cleanup_on_startup = true,
	cleanup_on_project_switch = true,
	cleanup_interval_hours = 24,
	max_file_check_per_run = 100,
}

local _config = vim.deepcopy(M.defaults)

function M.setup(opts)
	_config = vim.tbl_deep_extend("force", _config, opts or {})
	vim.fn.mkdir(_config.cache_root, "p")
end

function M.get()
	return _config
end

return M
