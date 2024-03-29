vim.loader.enable()
-- 加载基本配置
require("config.options")
-- lazy加载
require("config.lazy")
-- 加载状态栏模块
require("util.statusline")
-- 自定义函数和自定义按键映射
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		-- 加载自动命令
		require("config.autocmds")
		-- 加载按键
		require("config.keymaps")
	end,
})
