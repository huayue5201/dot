local opt = vim.opt

-- 空格按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- 禁止加载自带插件
vim.g.loaded_matchit = 1 -- matchit插件
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
vim.g.iloaded_netrwFileHandlers = 1 -- netrwFileHandlers插件

-- 鼠标设置
opt.mouse:append("a") -- 开启鼠标支持
opt.mousemoveevent = true -- 响应鼠标移动事件

-- 剪贴板设置
opt.clipboard:append("unnamedplus") -- 启用系统剪贴板

-- 编码设置
opt.encoding = "utf-8" -- 编码为utf-8

-- 按键设置
opt.updatetime = 300 -- 前置按键等待时间为300

-- 确认设置
opt.confirm = true -- 退出nvim时提示

-- 颜色设置
opt.termguicolors = true -- 开启真彩色

-- 折叠设置
opt.foldenable = true -- 启用折叠功能
function MyFoldtext()
	local ts_foldtext = vim.treesitter.foldtext()
	local n_lines = vim.v.foldend - vim.v.foldstart + 1
	local text_lines = (n_lines == 1) and "line" or "行"
	local additional_info = string.format(" %s %d%s", "", n_lines, text_lines)
	table.insert(ts_foldtext, { additional_info, { "Folded" } })
	return ts_foldtext
end
opt.foldtext:append("v:lua.MyFoldtext()") -- 设置折叠符号
opt.foldexpr:append("v:lua.vim.treesitter.foldexpr()") -- 开启treesitter折叠支持
opt.foldcolumn = "1" -- 折叠列为1
opt.foldmethod = "expr" -- 折叠方法"expr"
opt.foldlevel = 99 -- 折叠级别为99

-- 特殊字符设置
opt.list = true -- 显示特殊字符
opt.fillchars = {
	diff = "╱",
	eob = " ",
	fold = " ",
	vert = "│",
	msgsep = "‾",
	foldopen = "▾",
	foldsep = "│",
	foldclose = "▸",
}
opt.listchars = {
	tab = "┊ ",
	leadmultispace = "┊ ",
	trail = "␣",
	nbsp = "⍽",
}

-- 缩进设置
opt.autoindent = true -- 开启自动缩进
opt.expandtab = true -- tab转换为空格
opt.tabstop = 4 -- tab 4个空格
opt.shiftwidth = 3 -- 换行缩进3个空格

-- 换行设置
opt.wrap = false -- 长行禁止折叠

-- 滚动设置
opt.scrolloff = 8 -- 滚动偏移为8
opt.sidescrolloff = 8 -- 侧边滚动偏移为8

-- 备份设置
opt.backup = false -- 禁止文件备份

-- 会话设置
opt.sessionoptions:append("curdir,folds,globals,help,tabpages,terminal,winsize") -- 会话包含选项

-- 自动读取设置
opt.autoread = true -- 自动读取配置

-- 光标设置
opt.cursorline = true -- 高亮当前行

-- 菜单设置
opt.wildmenu = true -- 启用补全菜单样式设置
opt.pumheight = 15 -- 补全菜单高度为15
opt.wildoptions:append("pum") -- 命令行补全菜样式为"pum"

-- 拼写设置
opt.spelllang:append("en_us,cjk") -- 拼写语言为"en_us,cjk"

-- /?字符检索设置
opt.ignorecase = true -- 忽略大小写
opt.smartcase = true -- 智能大小写

-- 窗口分割设置
opt.splitbelow = true -- 下方显示
opt.splitright = true -- 右侧显示
opt.splitkeep = "screen" -- 窗口保持为"screen"
opt.splitkeep = "topline" -- 窗口保持为"topline"

-- 状态栏设置
vim.opt.showmode = false -- 禁止显示当前mode状态,由line插件代替
opt.laststatus = 3 -- 全局状态栏
opt.showtabline = 2 -- 始终显示状态栏
opt.cmdheight = 1 -- 命令行高度

-- 状态列设置
opt.statuscolumn:append("%s%{v:relnum?v:relnum:v:lnum}%=%C") -- 状态列样式
opt.signcolumn = "yes:1" -- ionc占用1格
opt.colorcolumn:append("80") -- 代码警示宽度80
opt.numberwidth = 4 -- 行号数字宽度为4
opt.number = true -- 显示行号
opt.relativenumber = true -- 显示相对行号
