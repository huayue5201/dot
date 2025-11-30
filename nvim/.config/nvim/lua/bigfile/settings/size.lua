-- lua/bigfile/settings/size.lua
local config_applier = require("bigfile.config_applier")
local state = require("bigfile.state")

local M = {}

M.name = "文件大小"

-- 大文件配置
M.bigfile = {
	configs = {
		function(buf)
			-- 禁用语法高亮和折叠以提升性能
			vim.bo.syntax = "off"
			vim.wo.foldmethod = "manual"
			vim.bo.swapfile = false

			-- 禁用 treesitter 高亮（如果可用）
			vim.cmd("TSDisable highlight")
		end,
	},
}

-- 小文件配置
M.smallfile = {
	configs = {
		function(buf)
			-- 启用语法高亮和折叠
			vim.bo.syntax = "on"
			vim.wo.foldmethod = "indent"
			vim.bo.swapfile = true

			-- 启用 treesitter 高亮（如果可用）
			vim.cmd("TSEnable highlight")
		end,
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
