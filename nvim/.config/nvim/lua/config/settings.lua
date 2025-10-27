-- -------------- Neovim 插件加载相关 --------------
-- 禁用 Perl 和 Ruby 提供者
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
-- 设置 Python3 提供者路径
vim.g.python3_host_prog = "/Users/lijia/python_project/re_choushibaike/.venv/bin/python3"

-- -------------- 基本设置 --------------
vim.opt.mousemoveevent = true -- 启用鼠标移动事件
vim.opt.fileencodings = { "utf-8", "gbk", "cp936", "ucs-bom", "latin1" }
vim.opt.inccommand = "split" -- 启用增量命令模式（即时显示命令效果）
vim.opt.clipboard = "unnamedplus" -- 使用系统剪贴板
-- vim.g.clipboard = "osc52"
vim.opt.modeline = false -- 禁用 modeline
vim.opt.updatetime = 300 -- 设置更新延迟时间（毫秒）
vim.opt.jumpoptions = "stack,view" -- 跳转选项：stack 和 view
vim.opt.cursorline = true -- 高亮当前行
vim.opt.cursorcolumn = true -- 启用当前列高亮
vim.g.vimsyn_embed = "alpPrj" -- 嵌入语法高亮
vim.opt.wrap = false -- 禁用自动换行
vim.opt.smoothscroll = true -- 开启平滑滚动
vim.opt.undofile = true -- 启用持久撤销
vim.opt.confirm = true -- 未保存退出确认
vim.opt.spelloptions = "camel" -- 开启驼峰拼写检查
-- vim.opt.messagesopt = "wait:500,history:1000" -- 消息选项：等待 500 毫秒，历史记录 1000 行
-- https://github.com/neovim/neovim/pull/27855
require("vim._extui").enable({
	enable = true, -- Whether to enable or disable the UI.
	msg = { -- Options related to the message module.
		---@type 'cmd'|'msg' Where to place regular messages, either in the
		---cmdline or in a separate ephemeral message window.
		target = "cmd",
		timeout = 4000, -- Time a message is visible in the message window.
	},
})

-- -------------- 折叠设置 --------------
-- 设置折叠表达式
vim.o.foldmethod = "expr"
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99 -- 默认展开所有内容
vim.opt.foldcolumn = "1" -- 显示折叠列
-- require("config.foldtext").custom_foldtext()

-- -------------- 编辑行为设置 --------------
vim.opt.expandtab = true -- 将 Tab 转为空格
vim.opt.tabstop = 2 -- 设置 Tab 为 2 个空格宽度
vim.opt.shiftwidth = 2 -- 设置自动缩进为 2 个空格
vim.opt.scrolloff = 8 -- 保持光标上方和下方至少 8 行可见
vim.opt.sidescrolloff = 5 -- 保持光标左右至少 5 列可见

-- shada设置
vim.opt.exrc = true -- 启用 exrc 配置
vim.opt.secure = true -- 启用安全模式
-- 生成唯一的 shada 文件路径
local workspace_path = vim.fn.getcwd()
local data_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8)
local shadafile = data_dir .. "/shada/" .. unique_id .. ".shada"
vim.opt.shadafile = shadafile
-- vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions" --会话设置

-- -------------- 补全设置 --------------
vim.bo.omnifunc = "" -- 禁用 omnifunc 补全
vim.opt.complete = "" -- 禁用补全
-- vim.opt.completeopt = "menuone,noinsert,noselect" -- 补全菜单的选项
vim.opt.completeopt = "menu,menuone,popup,fuzzy" -- 现代补全菜单

-- -------------- 搜索设置 --------------
vim.opt.ignorecase = true -- 搜索时忽略大小写
vim.opt.smartcase = true -- 智能区分大小写

-- -------------- 窗口和分割设置 --------------
vim.opt.splitbelow = true -- 新分割窗口默认在下方
vim.opt.splitright = true -- 新分割窗口默认在右边
vim.opt.splitkeep = "screen" -- 保持分割窗口屏幕位置
vim.opt.winborder = "rounded" -- 浮动窗口边框

-- -------------- 状态栏和标签页 --------------
vim.opt.showmode = false -- 禁用模式显示
vim.opt.laststatus = 3 -- 启用全局状态栏
vim.opt.cmdheight = 1 -- 状态栏高度 PS:< 0 noice插件会在启动时产生跳动
vim.opt.showtabline = 2 -- 始终显示标签页栏
vim.opt.statuscolumn = "%s%=%l%=%C "
vim.opt.number = true --显示行号
vim.opt.relativenumber = true -- 启用相对行号
vim.opt.signcolumn = "yes:3" -- 始终显示标志列
vim.opt.tabclose = "left,uselast" -- 关闭当前标签页后，会自动切换到最近使用过的标签页（如果有）

-- -------------- 显示和符号设置 --------------
vim.opt.list = true -- 显示不可见字符
vim.o.foldcolumn = "1"
vim.o.foldlevelstart = 99
vim.wo.foldtext = ""
vim.opt.fillchars = {
	stl = " ", -- 当前窗口的状态栏区域字符
	stlnc = " ", -- 非当前窗口的状态栏区域字符
	wbr = " ", -- winbar 区域字符
	-- 水平分隔符字符
	horiz = "━", -- 水平分隔符（例如 :split 使用）
	horizup = "┻", -- 向上的水平分隔符
	horizdown = "┳", -- 向下的水平分隔符
	-- 垂直分隔符字符
	vert = "┃", -- 垂直分隔符（例如 :vsplit 使用）
	vertleft = "┫", -- 向左的垂直分隔符
	vertright = "┣", -- 向右的垂直分隔符
	verthoriz = "╋", -- 垂直和水平重叠的分隔符
	-- 折叠相关字符
	fold = " ", -- 折叠文本填充字符
	-- foldopen = "󰛲", -- 折叠打开时的标记字符
	-- foldclose = "󰐖", -- 折叠关闭时的标记字符
	-- foldsep = "│", -- 打开折叠时的中间分隔符
	foldinner = " ",
	-- 其他
	diff = "╱", -- 显示差异时，已删除的行字符
	msgsep = "󰖰", -- 消息分隔符字符（例如用于 `display`）
	eob = " ", -- 空行字符（用于表示缓冲区末尾）
	lastline = "@", -- 最后一行或截断字符
}
vim.opt.foldtext = "v:lua.require('config.foldtext').custom_foldtext()"

vim.opt.listchars = {
	tab = "│ ", -- 显示 Tab 字符
	leadmultispace = "│ ", -- 显示多余空格
	multispace = " ",
	trail = "␣", -- 显示尾随空格
	nbsp = " ", -- 显示不间断空格
	eol = " ", -- 换行符
}

-- 全局 LSP 配置
vim.lsp.config("*", {
	root_markers = { ".git" },
	settings = {
		workspace = {
			didChangeWatchedFiles = {
				enabled = true,
			},
		},
	},
	capabilities = {
		textDocument = {
			semanticTokens = { multilineTokenSupport = true },
		},
	},
	on_attach = function(client)
		-- 确保 diagnostics 功能已启用
		client.server_capabilities.publishDiagnostics = true
	end,
})
