-- 把空格键设置为前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- 禁用自带插件
vim.g.loaded_netrw = 1 -- 文件管理器
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchit = 1 -- 高亮括号

-- 基本配置
vim.o.mouse = "a" -- 开启鼠标支持
vim.o.mousemoveevent = true -- 鼠标悬停事件
vim.o.encoding = "utf-8" -- 设定各种文本的字符编码
vim.o.confirm = true -- 退出vim询问是否保存
vim.o.clipboard = "unnamedplus" -- 是否启用系统剪切板

-- 折叠配置
function MyFoldtext()
	local ts_foldtext = vim.treesitter.foldtext()
	local n_lines = vim.v.foldend - vim.v.foldstart + 1
	local text_lines = (n_lines == 1) and " line" or " lines"
	local additional_info = "  " .. n_lines .. text_lines
	table.insert(ts_foldtext, { additional_info, { "Folded" } })
	return ts_foldtext
end
vim.opt.foldtext = "v:lua.MyFoldtext()"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- 设置 foldtext
vim.o.foldcolumn = "1" -- 折叠柱列数
vim.o.foldmethod = "expr"
vim.o.foldenable = true -- 自动开启折叠
vim.o.foldlevel = 99 -- 最大折叠层级

-- 设置特殊字符
vim.opt.list = true
vim.opt.fillchars = {
	diff = "╱", -- 在 diff 模式下，表示删除的字符
	eob = " ", -- 文件末尾的字符
	fold = " ", -- 折叠区域的字符
	vert = "│", -- 垂直分隔符，用于表示列
	msgsep = "‾", -- 状态栏中的消息分隔符
	foldopen = "▾", -- 表示折叠已打开的字符
	foldsep = "│", -- 折叠行之间的分隔符
	foldclose = "▸", -- 表示折叠已关闭的字符
}
vim.opt.listchars = {
	tab = "┊ ",
	leadmultispace = "┊ ",
	trail = "␣",
	nbsp = "⍽",
}

-- 代码缩进
vim.o.autoindent = true -- 继承前一行的缩进方式
vim.o.expandtab = true -- 使用空格替代tab
vim.o.tabstop = 3 -- 1个tab显示为3个空格
vim.o.softtabstop = 3 -- INSERT模式下1个tab代表3个空格
vim.o.shiftround = true -- NORMAL模式下>> <<和INSERT模式下CTRL-T CTRL-D的缩进长度
vim.o.shiftwidth = 3

-- 自动切换工作目录
-- vim.opt.autochdir=true
vim.o.termguicolors = true --设置 termguicolors 以启用突出显示组
vim.o.wrap = false -- 禁止折行显示文本
vim.o.scrolloff = 8 -- 光标移动的时候始终保持上下左右至少有 8 个空格的间隔
vim.o.sidescrolloff = 8
vim.o.backup = false -- 禁止创建备份文件
-- vim.o.writebackup = false
-- vim.o.noswapfile = false -- 禁止产生交换文件
vim.o.autoread = true -- 当文件被外部程序修改时，自动加载
vim.o.updatetime = 300 -- 缩短 swap file 的更新时间间隔
-- vim.o.timeoutlen = 500 -- 设定等待按键时长的毫秒数
vim.o.cursorline = true -- 高亮当前文本行
vim.o.termguicolors = true -- 开启xterm兼容的终端24位色彩支持
vim.o.wildmenu = true -- 补全增强
vim.o.pumheight = 15 -- 补全最多显示10行
vim.o.wildoptions = "pum" --"tagfile" cmd模式补全
vim.o.autoindent = true -- 是否开启自动缩进
vim.o.spelllang = "en_us,cjk" -- 设定单词拼写检查的语言
vim.o.ignorecase = true -- 不区分大小写的搜索，除非搜索中包含大写
vim.o.smartcase = true
vim.o.splitbelow = true -- 分隔窗口的时候 新窗口从下面或者右边出现
vim.o.splitright = true
vim.o.splitkeep = "screen" -- 稳定窗口
-- vim.o.splitkeep = "topline"
vim.o.laststatus = 3 -- 状态栏样式配置(1、2 、3)

-- 状态列配置
vim.o.statuscolumn = " %l%=%s%C"
vim.opt.signcolumn = "yes:1"
vim.opt.numberwidth = 3 -- 状态列宽度
vim.o.number = true -- 是否显示绝对行号
vim.o.relativenumber = true -- 显示相对行号
