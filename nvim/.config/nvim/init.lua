-- https://neovim.io/
-- https://devhints.io/vim
-- https://github.com/neovim/neovim/releases/tag/nightly

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 立即加载基础配置
require("core.settings") -- 基础 Neovim 选项
require("core.dotenv").load() -- 环境变量（须早于 core.pack，见 ~/.env）
require("core.pack") -- Neovim 自带 vim.pack + zpack 插件管理（懒加载由 zpack 负责）
require("lsp-config").setup() --lsp
require("fork-upstream").setup() -- 上游状态组件（状态栏 + :ForkUpstream），须早于状态栏以复用磁盘缓存
require("core.statusline") -- 状态栏（加载即自动构建并设置，无需手动调用 active）
require("core.tab_workspace").setup() -- 一个 tab 一个工作区（切 tab 隔离 buffer + 每 tab cwd + neo-tree 跟随）

-- 导航/窗口、自动命令、按键映射（三者合计仅 ~1.6ms，同步加载以避免启动后 300ms 内按键映射缺失）
require("core.navigation").setup() -- 导航/窗口：buffer 快捷键、buffer 设置、窗口尺寸守卫
require("core.autocmds") -- 加载自动命令
require("core.keymaps") -- 加载按键映射
