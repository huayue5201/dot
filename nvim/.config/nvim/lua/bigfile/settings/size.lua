local config_applier = require("bigfile.config_applier")
local info = require("bigfile.info")

local M = {}

M.name = "文件大小"

-- 大文件配置
M.bigfile = {
	options = {
		syntax = "off",
		foldmethod = "manual",
		swapfile = false,
	},
	plugin_commands = {
		-- "TSDisable", -- treesitter
	},
}

-- 小文件配置
M.smallfile = {
	options = {
		syntax = "on",
		foldmethod = "indent",
		swapfile = true,
	},
	plugin_commands = {
		-- "TSEnable", -- treesitter
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	info.add(
		buf,
		"size",
		"file too large",
		{ "syntax=off", "foldmethod=manual", "swapfile=false" },
		{ "treesitter", "cmp", "lsp" }
	)
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
end

return M
