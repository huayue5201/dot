local config_applier = require("bigfile.config_applier")
local state = require("bigfile.state")

local M = {}

M.name = "长行"

-- 大文件配置（长行优化）
M.bigfile = {
	configs = {
		"vim.opt.wrap = true",
		"vim.opt.cursorline = false",
		"vim.opt.textwidth = 1000",
		"vim.opt.linebreak = true",
		"vim.opt.showbreak = '↪ '",
		"vim.opt.sidescroll = 5",
		-- "vim.cmd('TSDisable highlight')",
	},
}

-- 小文件配置
M.smallfile = {
	configs = {
		"vim.opt.wrap = false",
		"vim.opt.cursorline = true",
		"vim.opt.textwidth = 0",
		"vim.opt.linebreak = false",
		"vim.opt.showbreak = ''",
		"vim.opt.sidescroll = 1",
		-- "vim.cmd('TSEnable highlight')",
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	state.set_rule_state(buf, "long_line", true, "long lines detected")
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
	state.set_rule_state(buf, "long_line", false, "恢复正常")
end

return M
