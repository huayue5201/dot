-- 禁止加载自带插件设置
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1

-- 禁止语言链接检测设置
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- 基本设置
vim.opt.encoding = "utf-8"
vim.opt.mousemoveevent = true
vim.opt.inccommand = "split"
vim.opt.clipboard = "unnamedplus"
vim.opt.modeline = false
vim.opt.timeout = true
vim.opt.updatetime = 300
vim.opt.jumpoptions = "stack"
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.foldenable = true
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldcolumn = "1"
vim.opt.foldmethod = "expr"
vim.opt.foldlevel = 99
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 5
vim.opt.wildmenu = true
vim.opt.pumheight = 15
vim.opt.wildoptions = "pum"
vim.opt.spelllang = { "en_us", "cjk" }
vim.opt.autoread = true
vim.opt.backup = false
vim.opt.wrap = false
vim.opt.confirm = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.grepprg = "rg --vimgrep --smart-case --hidden"
vim.opt.grepformat = "%f:%l:%c:%m"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.splitkeep = "screen"
vim.opt.showmode = false
vim.opt.laststatus = 3
vim.opt.showtabline = 2
vim.opt.cmdheight = 1
vim.opt.statuscolumn = "%=%{v:relnum?v:relnum:v:lnum}%s%C"
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "80"
vim.opt.number = true
vim.opt.relativenumber = true

-- 各种文本符号设置
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

-- 优化大文件打开性能
require("utils.largefile").setup()
