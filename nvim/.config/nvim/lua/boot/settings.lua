-- Neovim 选项按功能分类。
-- ui2 相关设置必须放在 require("ui.ui2").setup() 之后。

-- ================ 核心 UI / 消息 ================
require("ui.ui2").setup()

-- ================ 文件、编码与持久化 ================
vim.opt.fileencodings = { "utf-8", "gbk", "cp936", "ucs-bom", "latin1" }
vim.o.autoread = true -- 自动处理外部更改
vim.o.modeline = false -- 禁用 modeline
vim.o.undofile = true -- 启用持久撤销
vim.o.confirm = true -- 未保存退出确认

-- ================ 项目本地配置与会话 ================
-- 项目本地配置：安全边界由 :trust 信任列表控制，secure 在 Neovim 中已无实际作用
vim.o.exrc = true
-- 不设置 shadafile：使用 Neovim 默认的全局 shada（~/.local/state/nvim/shada/main.shada）
-- 多项目 tab / resession 场景下无法按项目隔离 shada，统一使用全局文件最稳定。
-- 不包含 options/localoptions：避免把 tabline/statusline/winbar 等含 v:lua 动态表达式的
-- 选项存进会话文件，否则重启恢复会话时选项引用的插件还没加载，会触发 nil 调用（如 nvim_bufferline/dropbar）。
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,globals,tabpages,winsize,winpos"

-- ================ 编辑行为 ================
vim.o.expandtab = true -- 将 Tab 转为空格
vim.o.tabstop = 2 -- Tab 显示宽度
vim.o.shiftwidth = 2 -- 自动缩进宽度
vim.opt.smartindent = true
vim.opt.smarttab = true
vim.o.nrformats = "unsigned" -- 数字增减不识别八进制/十六进制
vim.o.inccommand = "split" -- 增量命令预览（如 :s）
vim.o.jumpoptions = "stack,view" -- 跳转时保留视图并维护跳转栈
vim.o.updatetime = 300 -- 更新延迟（毫秒）

-- ================ 补全 ================
vim.bo.omnifunc = "" -- 禁用 omnifunc
vim.o.complete = "" -- 禁用内置补全来源
vim.o.completeopt = "menu,menuone,popup,fuzzy" -- 现代补全菜单

-- ================ 搜索 ================
vim.o.ignorecase = true -- 搜索忽略大小写
vim.o.smartcase = true -- 含大写时区分大小写

-- ================ 光标、滚动与高亮 ================
vim.opt.scrolloff = 8 -- 光标上下至少保留 8 行
vim.opt.scrolloffpad = 1
vim.o.sidescrolloff = 5 -- 光标左右至少保留 5 列
vim.o.sidescroll = 5 -- 水平滚动步长
vim.o.smoothscroll = true -- 平滑滚动
vim.o.cursorline = true -- 高亮当前行
-- cursorcolumn 关掉：实测每次移动+重绘从 0.45ms 涨到 1.14ms（2700 行，真 TTY），
-- 它一个就占了全部显示类额外开销的 84%，而体验收益远不如 cursorline。
-- 临时想看这一列，手动 :set cursorcolumn 即可。
vim.o.cursorcolumn = false
vim.opt.colorcolumn = "80" -- 第 80 列警示线
vim.opt.guicursor:append({
	"n-v-c-sm:block",
	"i-ci-ve:ver25",
	"r-cr-o:hor20",
	"t:ver25-blinkon500-blinkoff500-TermCursor",
})

-- ================ 换行与不可见字符 ================
vim.o.wrap = false -- 不自动换行
vim.o.linebreak = true -- 按单词边界换行
vim.o.showbreak = "↪ " -- 换行提示符
vim.o.list = true -- 显示不可见字符
vim.opt.listchars = {
	tab = "╎ ",
	multispace = " ",
	trail = "␣",
	nbsp = " ",
	eol = " ",
}
vim.opt.fillchars = {
	stl = " ", -- 当前窗口状态栏区域
	stlnc = " ", -- 非当前窗口状态栏区域
	wbr = " ", -- winbar 区域
	horiz = "", -- 水平分隔符
	horizup = "", -- 向上的水平分隔符
	horizdown = "", -- 向下的水平分隔符
	vert = "", -- 垂直分隔符
	vertleft = "", -- 向左的垂直分隔符
	vertright = "", -- 向右的垂直分隔符
	verthoriz = "", -- 垂直/水平重叠分隔符
	fold = " ", -- 折叠文本填充
	foldopen = "⊞", -- 折叠展开标记
	foldclose = "⊟", -- 折叠关闭标记
	foldsep = "│", -- 折叠中间分隔符
	foldinner = " ", -- 折叠层级填充
	diff = "╱", -- 差异删除行
	msgsep = " ", -- 消息分隔符
	eob = " ", -- 缓冲区末尾空行
	lastline = "@", -- 截断的最后一行
}

-- ================ 窗口与分割 ================
vim.o.splitbelow = true -- 新分割在下方
vim.o.splitright = true -- 新分割在右侧
vim.o.splitkeep = "screen" -- 调整分割时保持屏幕位置
vim.o.winborder = "rounded" -- 浮动窗口圆角边框
vim.opt.equalalways = false -- 不自动均分窗口

-- ================ 状态栏、标签页与行号 ================
vim.o.showmode = false -- 不在命令行显示模式
vim.o.laststatus = 3 -- 全局状态栏
vim.o.cmdheight = 0 -- 命令行高度；ui2 下为 0 可避免跳动
vim.o.showtabline = 2 -- 始终显示标签页栏
-- statuscolumn / signcolumn 由 luukvbaal/statuscol.nvim 接管（见 lua/plugins/statuscol.lua）：
-- 下列两行是插件加载前的回退值。
vim.o.statuscolumn = "%s%=%l%=%C "
vim.o.signcolumn = "yes:3"
vim.o.number = true -- 显示行号
vim.o.relativenumber = true -- 相对行号
vim.o.tabclose = "left,uselast" -- 关闭标签页后切到最近使用的标签页

-- ================ 折叠 ================
-- 折叠表达式由插件接管，这里只保留折叠列；statuscolumn 的 %C 依赖它。
vim.o.foldcolumn = "1"

-- ================ 系统集成与语法 ================
vim.o.mousemoveevent = true -- 启用鼠标移动事件
vim.g.vimsyn_embed = "alpPrj" -- 嵌入语法高亮
vim.schedule(function()
	vim.opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- 同步系统剪贴板
end)
