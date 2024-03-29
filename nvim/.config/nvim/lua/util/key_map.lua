-- util.keyMap.lua

local M = {}

M.setKeymap = function(modes, lhs, rhs, opts)
	opts = opts or {}

	-- 设置默认值
	opts.unique = opts.unique == nil and true or opts.unique
	opts.noremap = opts.noremap == nil and true or opts.noremap
	opts.silent = opts.silent == nil and true or opts.silent

	vim.keymap.set(modes, lhs, rhs, opts)
end

return M
