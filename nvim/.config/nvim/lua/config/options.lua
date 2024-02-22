-- 把空格键设置为前置按键
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
vim.o.mouse = "a" -- 设置鼠标为可用状态
vim.o.mousemoveevent = true -- 设置鼠标移动事件为true

-- 编码设置
vim.o.encoding = "utf-8" -- 设置编码为utf-8

-- 确认设置
vim.o.confirm = true -- 设置确认为true

-- 剪贴板设置
vim.o.clipboard = "unnamedplus" -- 设置剪贴板为"unnamedplus"

-- 颜色设置
vim.o.termguicolors = true -- 设置termguicolors为true

-- 折叠设置
function MyFoldtext()
    local ts_foldtext = vim.treesitter.foldtext()
    local n_lines = vim.v.foldend - vim.v.foldstart + 1
    local text_lines = (n_lines == 1) and "line" or "行"
    local additional_info = string.format(" %s %d%s", "", n_lines, text_lines)
    table.insert(ts_foldtext, { additional_info, { "Folded" } })
    return ts_foldtext
end
vim.opt.foldtext = "v:lua.MyFoldtext()" -- 设置折叠文本为v:lua.MyFoldtext()
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- 设置折叠表达式为v:lua.vim.treesitter.foldexpr()
vim.o.foldcolumn = "1" -- 设置折叠列为"1"
vim.o.foldmethod = "expr" -- 设置折叠方法为"expr"
vim.o.foldenable = true -- 设置折叠为true
vim.o.foldlevel = 99 -- 设置折叠级别为99

-- 特殊字符设置
vim.opt.list = true -- 设置显示特殊字符为true
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

-- 缩进设置
vim.o.autoindent = true -- 设置自动缩进为true
vim.o.expandtab = true -- 设置扩展标签为true
vim.o.tabstop = 3 -- 设置制表符为3
vim.o.softtabstop = 3 -- 设置软制表符为3
vim.o.shiftwidth = 3 -- 设置换行缩进为3

-- 换行设置
vim.o.wrap = false -- 设置换行为false

-- 滚动设置
vim.o.scrolloff = 8 -- 设置滚动偏移为8
vim.o.sidescrolloff = 8 -- 设置侧边滚动偏移为8

-- 备份设置
vim.o.backup = false -- 设置备份为false

-- 会话设置
vim.opt.sessionoptions = "curdir,folds,globals,help,tabpages,terminal,winsize" -- 设置会话选项

-- 自动读取设置
vim.o.autoread = true -- 设置自动读取为true

-- 更新时间设置
vim.o.updatetime = 300 -- 设置更新时间为300

-- 光标设置
vim.o.cursorline = true -- 设置光标行为true

-- 菜单设置
vim.o.wildmenu = true -- 设置菜单为true
vim.o.pumheight = 15 -- 设置弹出菜单高度为15
vim.o.wildoptions = "pum" -- 设置命令行菜选项为"pum"

-- 拼写设置
vim.o.spelllang = "en_us,cjk" -- 设置拼写语言为"en_us,cjk"

-- 大小写设置
vim.o.ignorecase = true -- 设置忽略大小写为true
vim.o.smartcase = true -- 设置智能大小写为true

-- 窗口分割设置
vim.o.splitbelow = true -- 设置分割下方为true
vim.o.splitright = true -- 设置分割右侧为true
vim.o.splitkeep = "screen" -- 设置分割保持为"screen"
vim.o.splitkeep = "topline" -- 设置分割保持为"topline"

-- 状态设置
vim.o.laststatus = 2 -- 设置状态栏行为2
vim.o.showtabline = 2 -- 设置显示标签行为2
vim.opt.statuscolumn = " %=%{v:relnum?v:relnum:v:lnum}%=%s%C" -- 设置状态列
vim.opt.signcolumn = "yes:1" -- 设置标志列
vim.opt.colorcolumn = "80" -- 设置颜色列为80
vim.opt.numberwidth = 4 -- 设置数字宽度为4
vim.o.number = true -- 设置数字为 true
vim.o.relativenumber = true -- 设置相对数字为true
