local config_applier = require("bigfile.config_applier")
local info = require("bigfile.info")

local M = {}

M.name = "行数"

-- 大文件配置
M.bigfile = {
	options = {
		wrap = false,
		cursorline = false,
		cursorcolumn = false,
		number = false,
		relativenumber = false,
	},
	plugin_commands = {
		"TSBufDisable indent",
	},
}

-- 小文件配置
M.smallfile = {
	options = {
		wrap = true,
		cursorline = true,
		cursorcolumn = false,
		number = true,
		relativenumber = true,
	},
	plugin_commands = {
		"TSBufEnable indent",
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	info.add(
		buf,
		"lines",
		"too many lines",
		{ "wrap=false", "cursorline=false", "cursorcolumn=false", "number=false", "relativenumber=false" },
		{ "treesitter", "indent_blankline" }
	)
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
end

return M
