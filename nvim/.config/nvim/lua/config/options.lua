-- 禁止加载自带插件设置
-- vim.g.loaded_matchit = 1 -- matchit插件
-- vim.g.loaded_matchparen = 1
vim.g.loaded_gzip = 1 -- gzip插件
vim.g.loaded_tar = 1 -- tar插件
vim.g.loaded_tarPlugin = 1 -- tarPlugin插件
vim.g.loaded_zip = 1 -- zip插件
vim.g.loaded_zipPlugin = 1 -- zipPlugin插件
vim.g.loaded_getscript = 1 -- getscript插件
vim.g.loaded_getscriptPlugin = 1 --getscriptPlugin插件
vim.g.loaded_vimball = 1 -- vimball插件
vim.g.loaded_vimballPlugin = 1 -- vimballPlugin插件
vim.g.loaded_2html_plugin = 1 -- 2html_plugin插件
vim.g.loaded_logiPat = 1 -- logiPat插件
vim.g.loaded_rrhelper = 1 -- rrhelper插件
vim.g.loaded_netrw = 1 -- netrw插件
vim.g.loaded_netrwPlugin = 1 -- netrwPlugin插件
vim.g.loaded_netrwSettings = 1 -- netrwSettings插件
vim.g.iloaded_netrwFileHandlers = 1 --

-- 禁止语言链接检测设置
vim.g.loaded_perl_provider = 0 -- perl
vim.g.loaded_ruby_provider = 0 -- ruby

vim.opt.mouse:append("a") -- 开启鼠标支持

vim.opt.clipboard:append("unnamedplus") -- 启用系统剪贴板

vim.opt.encoding = "utf-8" -- 编码为utf-8
-- vim.bo.commentstring = "//%s" -- 注释格式
vim.opt.inccommand = "split" -- 键入时实时预览
vim.opt.modeline = false -- 开启此选项会导致报错

vim.opt.updatetime = 300 -- 前置按键等待时间为300
vim.opt.jumpoptions:append("stack") -- "stack" 修改C-o/C-i的跳转行为

vim.opt.termguicolors = true -- 开启真彩色
vim.opt.cursorline = true -- 高亮当前行

vim.opt.list = true -- 显示特殊字符
vim.opt.fillchars = {
	diff = "╱",
	eob = " ",
	fold = " ",
	vert = "│",
	msgsep = "‾",
	foldopen = "▾",
	foldsep = "│",
	foldclose = "▸",
}
vim.opt.listchars = {
	tab = "┊ ",
	leadmultispace = "┊ ",
	trail = "␣",
	nbsp = "⍽",
}

vim.opt.foldenable = true -- 启用折叠功能
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- 开启treesitter折叠支持
vim.opt.foldcolumn = "1" -- 折叠列为1
vim.opt.foldmethod = "expr" -- 折叠方法"expr"
vim.opt.foldlevel = 99 -- 折叠级别为99

vim.opt.autoindent = true -- 开启自动缩进
vim.opt.expandtab = true -- tab转换为空格
vim.opt.tabstop = 2 -- tab 4个空格
vim.opt.shiftwidth = 2 -- 换行缩进3个空格

vim.opt.scrolloff = 8 -- 上下滚动始终保持5行距离
vim.opt.sidescrolloff = 5 -- 侧边滚动始终保持5列距离

vim.opt.sessionoptions:append("curdir,folds,globals,help,tabpages,terminal,winsize") -- 持久保存session需要包含的内容

vim.opt.wildmenu = true -- 允许补全菜单样式配置
vim.opt.pumheight = 15 -- 补全菜单高度为15
vim.opt.wildoptions:append("pum") -- 命令行补全菜样式为"pum"

vim.opt.spelllang:append("en_us,cjk") -- 拼写语言为"en_us,cjk"
-- vim.opt.autochdir = true -- 自动cd到当前buffer所属目录
vim.opt.autoread = true -- 更改后自动读取
-- vim.opt.autowrite = true -- 自动写入
vim.opt.backup = false -- 禁止文件自动备份
vim.opt.wrap = false -- 长行禁止自动换行显示
vim.opt.confirm = true -- 代码未保存时退出,nvim提示是否保存

vim.opt.ignorecase = true -- 忽略大小写
vim.opt.smartcase = true -- 智能大小写
vim.opt.grepprg = "rg --vimgrep --smart-case --hidden" -- 用rg代替grep
vim.opt.grepformat:append("%f:%l:%c:%m") -- grep输出格式设置

vim.opt.splitbelow = true -- 下方显示
vim.opt.splitright = true -- 右侧显示
vim.opt.splitkeep = "screen" -- 窗口保持为"screen"
-- opt.splitkeep = "topline" -- 窗口保持为"topline"

vim.opt.showmode = false -- 禁止显示当前mode状态,由插件提供
vim.opt.laststatus = 3 -- 全局状态栏
vim.opt.showtabline = 2 -- 始终显示状态栏
vim.opt.cmdheight = 1 -- 命令行高度

-- vim.opt.statuscolumn = [[%!v:lua.require('util.status').Status.statuscolumn()]]
vim.opt.statuscolumn:append("%=%{v:relnum?v:relnum:v:lnum}%s%C") -- 状态列样式
vim.opt.signcolumn = "yes" -- ionc占用几格
vim.opt.colorcolumn:append("80") -- 代码警示宽度80
vim.opt.number = true -- 显示行号
vim.opt.relativenumber = true -- 显示相对行号
