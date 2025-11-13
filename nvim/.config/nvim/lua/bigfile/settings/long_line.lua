local config_applier = require("bigfile.config_applier")
local info = require("bigfile.info")

local M = {}

M.name = "长行"

-- 大文件配置（长行优化）
M.bigfile = {
	options = {
		wrap = true, -- 开启软换行
		cursorline = false,
		textwidth = 1000, -- 超过1000列才换行
		linebreak = true, -- 单词边界换行
		showbreak = "↪ ", -- 换行提示符
		sidescroll = 5, -- 水平滚动步长
	},
	plugin_commands = {
		-- "TSDisable", -- treesitter
	},
}

-- 小文件配置
M.smallfile = {
	options = {
		wrap = false,
		cursorline = true,
		textwidth = 0, -- 不限制文本宽度
		linebreak = false,
		showbreak = "",
		sidescroll = 1,
	},
	plugin_commands = {
		-- "TSEnable", -- treesitter
	},
}

function M.apply(buf)
	config_applier.apply_config(M.bigfile, buf)
	info.add(
		buf,
		"long_line",
		"long lines detected",
		{ "wrap=true", "cursorline=false", "textwidth=1000", "linebreak=true", "showbreak=↪", "sidescroll=5" },
		{ "treesitter" }
	)
end

function M.reset(buf)
	config_applier.apply_config(M.smallfile, buf)
end

return M
