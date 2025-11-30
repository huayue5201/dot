-- lua/bigfile/settings/lines.lua
local config_applier = require("bigfile.config_applier")
local state = require("bigfile.state")

local M = {}

M.name = "行数"

-- 大文件配置 - 使用函数方式
M.bigfile = {
	configs = {
		function(buf)
			-- 禁用交换文件和更新计数
			vim.opt.updatecount = 0
			vim.bo[buf].swapfile = false

			-- 禁用光标行和列高亮以提升性能
			vim.wo.cursorline = false
			vim.wo.cursorcolumn = false

			-- 禁用 treesitter 缩进（如果可用）
			vim.cmd("TSBufDisable indent")
		end,
	},
}

-- 小文件配置
M.smallfile = {
	configs = {
		function(buf)
			-- 启用交换文件和更新计数
			vim.opt.updatecount = 300
			vim.bo[buf].swapfile = true

			-- 启用光标行高亮
			vim.wo.cursorline = true
			vim.wo.cursorcolumn = false

			-- 启用 treesitter 缩进（如果可用）
			vim.cmd("TSBufEnable indent")
		end,
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
