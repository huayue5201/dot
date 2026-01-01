-- json_store/core/config.lua
local M = {}

M.defaults = {
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v6/",
	auto_save = true,
	save_delay_ms = 1500,

	-- 哪些 namespace 存在于 global project
	global_namespaces = { "todo_links", "code_links", "marks" },

	-- diff debounce 延迟（TextChanged → 延迟 diff）
	sync_delay_ms = 300,

	----------------------------------------------------------------------
	-- 可配置的路径忽略列表（prefix 或 Lua pattern）
	----------------------------------------------------------------------
	ignore_paths = {
		-- 系统目录
		"/usr/",
		"/System/",
		"/private/",
		"/tmp/",
		"/var/",

		-- 虚拟 buffer（UI 组件）
		"neo%-tree",
		"Grug FAR",
		"Find and Replace",
	},
}

-- 当前配置（深拷贝默认值）
local _config = vim.deepcopy(M.defaults)

----------------------------------------------------------------------
-- setup：用户可覆盖默认配置
----------------------------------------------------------------------
function M.setup(opts)
	_config = vim.tbl_deep_extend("force", _config, opts or {})
	vim.fn.mkdir(_config.cache_root, "p")
end

----------------------------------------------------------------------
-- get：获取当前配置
----------------------------------------------------------------------
function M.get()
	return _config
end

return M
