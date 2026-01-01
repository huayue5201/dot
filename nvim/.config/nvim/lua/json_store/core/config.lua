-- json_store/core/config.lua
local M = {}

M.defaults = {
	cache_root = vim.fn.stdpath("cache") .. "/project_states_v6/",
	auto_save = true,
	save_delay_ms = 1500,
	global_namespaces = { "todo_links", "code_links", "marks" },

	-- diff debounce 延迟（TextChanged → 延迟 diff）
	sync_delay_ms = 300,
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
