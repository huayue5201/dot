-- lua/bigfile/settings/lines.lua
local config_applier = require("bigfile.config_applier")
local state = require("bigfile.state")

local M = {}

M.name = "行数"

-- 大文件配置 - 直接使用 vim.opt 和 vim.cmd 格式
M.bigfile = {
	configs = {
		"vim.opt.updatecount = 0",
		"vim.o.swapfile = false",
		"vim.opt.cursorline = false",
		"vim.opt.cursorcolumn = false",
		"vim.cmd('TSBufDisable indent')",
	},
}

-- 小文件配置
M.smallfile = {
	configs = {
		"vim.opt.updatecount = 300",
		"vim.o.swapfile = true",
		"vim.opt.cursorline = true",
		"vim.opt.cursorcolumn = false",
		"vim.cmd('TSBufEnable indent')",
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	state.set_rule_state(buf, "lines", true, "too many lines")
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
	state.set_rule_state(buf, "lines", false, "恢复正常")
end

return M
