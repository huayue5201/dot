-- lua/bigfile/settings/size.lua
local config_applier = require("bigfile.config_applier")
local state = require("bigfile.state")

local M = {}

M.name = "文件大小"

M.bigfile = {
	configs = {
		"vim.opt.syntax = 'off'",
		"vim.opt.foldmethod = 'manual'",
		"vim.opt.swapfile = false",
		"vim.cmd('TSDisable highlight')",
	},
}

M.smallfile = {
	configs = {
		"vim.opt.syntax = 'on'",
		"vim.opt.foldmethod = 'indent'",
		"vim.opt.swapfile = true",
		"vim.cmd('TSEnable highlight')",
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	state.set_rule_state(buf, "size", true, "file too large")
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
	state.set_rule_state(buf, "size", false, "恢复正常")
end

return M
