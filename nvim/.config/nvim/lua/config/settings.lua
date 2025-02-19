-- 禁止加载 Neovim 自带插件
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

-- 禁用某些语言的提供者（比如 Perl 和 Ruby）
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- 基本设置
vim.opt.mousemoveevent = true -- 启用鼠标移动事件
vim.opt.inccommand = "split" -- 增量命令模式
vim.opt.clipboard = "unnamedplus" -- 使用系统剪贴板
vim.opt.modeline = false -- 禁用 modeline
vim.opt.updatetime = 300 -- 设置更新延迟时间（毫秒）
vim.opt.jumpoptions = "stack" -- 启用跳转历史堆栈
vim.opt.cursorline = true -- 高亮当前行
vim.opt.wrap = false -- 禁用自动换行

-- 折叠设置
vim.opt.foldmethod = "expr" -- 设置折叠方法为表达式
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- 使用 Treesitter 表达式进行折叠
vim.opt.foldcolumn = "1" -- 显示折叠列
vim.opt.foldlevel = 99 -- 设置折叠级别

-- 编辑行为设置
vim.opt.expandtab = true -- 将 Tab 转换为空格
vim.opt.tabstop = 2 -- 设置 Tab 为 2 个空格宽度
vim.opt.shiftwidth = 2 -- 设置自动缩进为 2 个空格
vim.opt.scrolloff = 8 -- 保持光标上方和下方至少 8 行可见
vim.opt.sidescrolloff = 5 -- 保持光标左右至少 5 列可见

-- 补全设置
vim.bo.omnifunc = "" -- 禁用 omnifunc 补全
vim.opt.complete = "" -- 禁用补全
vim.opt.completeopt = "menuone,noinsert,noselect" -- 补全菜单的选项
-- vim.o.completeopt = "menu,menuone,popup,fuzzy" -- modern completion menu

-- 搜索设置
vim.opt.grepprg = "rg --vimgrep --smart-case --hidden" -- 使用 ripgrep 作为搜索程序
vim.opt.grepformat = "%f:%l:%c:%m" -- 设置 grep 格式
vim.opt.ignorecase = true -- 忽略大小写
vim.opt.smartcase = true -- 在搜索时，智能区分大小写

-- 工作区配置 (`shada` 文件)
vim.opt.exrc = true -- 启用 exrc 配置，允许在当前工作目录加载配置文件
vim.opt.secure = true -- 启用安全模式，防止加载不安全的配置文件
-- 生成唯一的 `shada` 文件路径
local workspace_path = vim.fn.getcwd() -- 获取当前工作目录的路径
local cache_dir = vim.fn.stdpath("data") -- 获取 Neovim 的缓存目录路径
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8) ---@type string
local shadafile = cache_dir .. "/myshada/" .. unique_id .. ".shada" -- 根据唯一 ID 生成 `shada` 文件的存储路径
vim.opt.shadafile = shadafile -- 设置 `shada` 文件路径

-- 窗口和分割设置
vim.opt.splitbelow = true -- 新分割窗口默认在下方
vim.opt.splitright = true -- 新分割窗口默认在右边
vim.opt.splitkeep = "screen" -- 保持分割窗口的屏幕位置

-- 状态栏和标签页
vim.opt.showmode = false -- 禁用模式显示
vim.opt.laststatus = 3 -- 显示全局状态栏
vim.opt.showtabline = 2 -- 永远显示标签页栏
vim.opt.statuscolumn = "%!v:lua.require('config.statucolumn').active()" -- 载入 statuscolumn 配置
-- vim.opt.statuscolumn = " %s%=%l  %C" -- 状态列显示相对行号和其他信息
vim.opt.relativenumber = true -- 相对行号
vim.opt.signcolumn = "yes" -- 总是显示标志列

-- 显示和符号设置
vim.opt.list = true -- 显示不可见字符
vim.opt.fillchars = {
	diff = "╱", -- 区分符号
	eob = " ", -- 空行字符
	fold = " ", -- 折叠符号
	vert = "│", -- 垂直分割符号
	msgsep = "‾", -- 消息分隔符
	foldopen = "▾", -- 折叠打开符号
	foldsep = "│", -- 折叠分隔符
	foldclose = "▸", -- 折叠关闭符号
}

vim.opt.listchars = {
	tab = "┊ ", -- 显示 Tab 字符
	leadmultispace = "┊ ", -- 显示多余空格
	multispace = "┊ ",
	trail = "␣", -- 显示尾随空格
	nbsp = "⍽", -- 显示不间断空格
	eol = "↲", -- 换行符
}
