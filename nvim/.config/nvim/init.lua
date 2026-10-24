-- https://neovim.io/
-- https://devhints.io/vim
-- https://github.com/neovim/neovim/releases/tag/nightly

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 立即加载基础配置
require("boot.compat") -- 只吞掉上游插件的 `client.supports_method` 弃用提示
require("boot.settings") -- 基础 Neovim 选项
require("boot.dotenv").load() -- 环境变量（须早于 boot.pack，见 ~/.env）

-- 启动前修补：mason bin 进 PATH（否则启动即开文件时 LSP 找不到二进制）、LSP 日志轮转
local preflight = require("boot.preflight")
preflight.setup_mason_path()
preflight.rotate_lsp_log()
-- rustowl 的 target/owl 产物清理：延迟到启动完成后再跑（du 统计要几百毫秒）
vim.defer_fn(function()
	pcall(preflight.clean_stale_owl, 200)
end, 3000)

require("boot.pack") -- 原生 vim.pack 安装 + 自带 eager 加载器（见 lua/boot/pack.lua 顶部说明）
require("lsp_ext").setup() --lsp
require("feat.fork_upstream").setup() -- 上游状态组件（状态栏 + :ForkUpstream），须早于状态栏以复用磁盘缓存
require("ui.statusline") -- 状态栏（加载即自动构建并设置，无需手动调用 active）
require("feat.tab_workspace").setup() -- 一个 tab 一个工作区（切 tab 隔离 buffer + 每 tab cwd + neo-tree 跟随）

-- 导航/窗口、自动命令、按键映射（三者合计仅 ~1.6ms，同步加载以避免启动后 300ms 内按键映射缺失）
require("feat.navigation").setup() -- 导航/窗口：buffer 快捷键、buffer 设置、窗口尺寸守卫
require("boot.autocmds") -- 加载自动命令
require("boot.keymaps") -- 加载按键映射
require("local.textdiff").setup() -- 本地小模块：选区文本对比（:Diff / 可视模式 D、gD，见 lua/local/textdiff.lua）
require("local.lightbulb").setup() -- 本地小模块：code action 行末灯泡浮窗（替代 nvim-lightbulb，见 lua/local/lightbulb.lua）
