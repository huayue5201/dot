-- lua/bigfile/init.lua
local M = {}

function M.setup(opts)
	opts = opts or {}
	require("bigfile.autocmd").setup(opts)
	require("bigfile.commands").setup_commands()
end

return M
