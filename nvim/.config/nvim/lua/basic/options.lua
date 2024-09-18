-- 禁止加载自带插件设置
local disabled_plugins = {
	"gzip", -- gzip 插件
	"tar", -- tar 插件
	"tarPlugin", -- tarPlugin 插件
	"zip", -- zip 插件
	"zipPlugin", -- zipPlugin 插件
	"getscript", -- getscript 插件
	"getscriptPlugin", -- getscriptPlugin 插件
	"vimball", -- vimball 插件
	"vimballPlugin", -- vimballPlugin 插件
	"2html_plugin", -- 2html_plugin 插件
	"logiPat", -- logiPat 插件
	"rrhelper", -- rrhelper 插件
	"netrw", -- netrw 插件
	"netrwPlugin", -- netrwPlugin 插件
	"netrwSettings", -- netrwSettings 插件
	"netrwFileHandlers", -- netrwFileHandlers 插件
}
for _, plugin in ipairs(disabled_plugins) do
	vim.g["loaded_" .. plugin] = 1
end

-- 禁止语言链接检测设置
local disabled_providers = {
	"perl_provider", -- 禁止 perl 提供者
	"ruby_provider", -- 禁止 ruby 提供者
}
for _, provider in ipairs(disabled_providers) do
	vim.g["loaded_" .. provider] = 0
end

-- 基本设置
local basic_options = {
	encoding = "utf-8", -- 设置编码为 utf-8
	mousemoveevent = true, -- 检测鼠标移动事件
	inccommand = "split", -- 输入时实时预览
	clipboard = "unnamedplus", -- 启用系统剪贴板
	modeline = false, -- 禁用 modeline
	timeout = true,
	updatetime = 300, -- 更新时间为 300 毫秒
	jumpoptions = "stack", -- 修改 C-o/C-i 的跳转行为
	cursorline = true, -- 高亮当前行
	list = true, -- 显示特殊字符
	foldenable = true, -- 启用折叠功能
	foldexpr = "v:lua.vim.treesitter.foldexpr()", -- 开启 treesitter 折叠支持
	foldcolumn = "1", -- 折叠列为 1
	foldmethod = "expr", -- 折叠方法 "expr"
	foldlevel = 99, -- 折叠级别为 99
	autoindent = true, -- 开启自动缩进
	expandtab = true, -- tab 转换为空格
	tabstop = 2, -- tab 为 2 个空格
	shiftwidth = 2, -- 换行缩进 2 个空格
	scrolloff = 8, -- 上下滚动始终保持 8 行距离
	sidescrolloff = 5, -- 侧边滚动始终保持 5 列距离
	wildmenu = true, -- 允许补全菜单样式配置
	pumheight = 15, -- 补全菜单高度为 15
	wildoptions = "pum", -- 命令行补全菜样式为 "pum"
	spelllang = "en_us,cjk", -- 拼写语言为 "en_us,cjk"
	autoread = true, -- 更改后自动读取
	backup = false, -- 禁止文件自动备份
	wrap = false, -- 长行禁止自动换行显示
	confirm = true, -- 代码未保存时退出, nvim 提示是否保存
	ignorecase = true, -- 忽略大小写
	smartcase = true, -- 智能大小写
	grepprg = "rg --vimgrep --smart-case --hidden", -- 用 rg 代替 grep
	grepformat = "%f:%l:%c:%m", -- grep 输出格式设置
	splitbelow = true, -- 下方显示
	splitright = true, -- 右侧显示
	splitkeep = "screen", -- 窗口保持为 "screen"
	showmode = false, -- 禁止显示当前 mode 状态, 由插件提供
	laststatus = 3, -- 全局状态栏
	showtabline = 2, -- 始终显示状态栏
	cmdheight = 1, -- 命令行高度
	statuscolumn = "%=%{v:relnum?v:relnum:v:lnum}%s%C", -- 状态列样式
	signcolumn = "yes", -- icon 占用几格
	colorcolumn = "80", -- 代码警示宽度 80
	number = true, -- 显示行号
	relativenumber = true, -- 显示相对行号
}
for option, value in pairs(basic_options) do
	vim.opt[option] = value
end

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
