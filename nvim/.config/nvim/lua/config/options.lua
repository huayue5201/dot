-- 把空格键设置为前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 禁用自带插件
vim.g.loaded_netrw = 1 -- 文件管理器
vim.g.loaded_netrwPlugin = 1
-- vim.g.loaded_matchit = 1 -- 高亮括号

-- 鼠标
vim.o.mouse = "a" -- 开启鼠标支持
vim.o.mousemoveevent = true -- 鼠标悬停事件

-- 代码折叠
-- vim.o.foldmethod = "expr"
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()" -- treesitter做为折叠引擎
-- vim.o.foldenable = false -- 禁用自动折叠
-- vim.o.foldlevel = 99 -- 最大折叠层级

-- 代码缩进
vim.o.expandtab = true -- 使用空格替代tab
vim.o.tabstop = 3 -- 1个tab显示为3个空格
vim.o.softtabstop = 3 -- INSERT模式下1个tab代表3个空格
vim.g.autoindent = true -- 继承前一行的缩进方式
-- NORMAL模式下>> <<和INSERT模式下CTRL-T CTRL-D的缩进长度
vim.o.shiftround = true
vim.o.shiftwidth = 3

-- 自动切换工作目录
-- vim.opt.autochdir=true
-- set termguicolors to enable highlight groups
vim.o.termguicolors = true
-- 设定各种文本的字符编码
vim.o.encoding = "utf-8"
-- 状态栏样式配置(1、2 、3)
vim.o.laststatus = 3
-- 退出vim询问是否保存
vim.o.confirm = true
-- 是否显示绝对行号
vim.o.number = true
-- 显示相对行号
vim.o.relativenumber = true
-- 是否启用系统剪切板
vim.o.clipboard = "unnamedplus"
-- 禁止折行显示文本
vim.o.wrap = false
-- 光标移动的时候始终保持上下左右至少有 8 个空格的间隔
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
-- 禁止创建备份文件
vim.o.backup = false
-- vim.o.writebackup = false
-- 禁止产生交换文件
vim.o.noswapfile = false
-- 当文件被外部程序修改时，自动加载
vim.o.autoread = true
-- 缩短 swap file 的更新时间间隔
vim.o.updatetime = 300
-- 设定等待按键时长的毫秒数
-- vim.o.timeoutlen = 500
-- 是否高亮当前文本行
vim.o.cursorline = true
-- 是否开启 xterm 兼容的终端 24 位色彩支持
vim.o.termguicolors = true
-- 自动补全不自动选中
vim.g.completeopt = "menu,menuone,noselect,noinsert"
-- 补全增强
vim.o.wildmenu = true
-- 补全最多显示10行
vim.o.pumheight = 15
-- 是否开启自动缩进
vim.o.autoindent = true
-- 设定单词拼写检查的语言
vim.o.spelllang = "en_us,cjk"
-- 不区分大小写的搜索，除非搜索中包含大写
vim.o.ignorecase = true
vim.o.smartcase = true
-- 显示特殊字符
-- vim.opt.list = true
-- vim.opt.listchars = { space = "▫", tab = "--" }
-- 显示左侧图标指示列
vim.wo.signcolumn = "yes"
-- 分隔窗口的时候 新窗口从下面或者右边出现
vim.o.splitbelow = true
vim.o.splitright = true
-- 稳定窗口
vim.o.splitkeep = "screen"
-- vim.o.splitkeep = "topline"
