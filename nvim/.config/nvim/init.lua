-- Lua加载器功能,提高启动速度
vim.loader.enable()
-- 加载基本配置
require("config.options")
-- 加载按键
require("config.keymaps")
-- 加载自动命令
require("config.autocmds")
-- lazy加载
require("config.lazy")
-- 加载状态栏模块
require("user.statusline")
