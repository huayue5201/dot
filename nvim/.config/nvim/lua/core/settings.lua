-------------- Neovim 插件加载相关 --------------
-- vim.ui.select = require("user.simple-select")
-- 禁用 Perl 和 Ruby 提供者
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
-- 设置 Python3 提供者路径
-- vim.g.python3_host_prog = "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3"

-- -------------- 基本设置 --------------
vim.o.mousemoveevent = true -- 启用鼠标移动事件
vim.opt.fileencodings = { "utf-8", "gbk", "cp936", "ucs-bom", "latin1" }
vim.o.inccommand = "split" -- 启用增量命令模式（即时显示命令效果）
vim.schedule(function()
	vim.opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus" -- Sync with system clipboard
end)
-- vim.g.clipboard = "osc52"
vim.o.modeline = false -- 禁用 modeline
-- vim.o.updatetime = 10000 -- 设置更新延迟时间（毫秒）
vim.o.jumpoptions = "stack,view" -- 跳转选项：stack 和 view
vim.o.cursorline = true -- 高亮当前行
vim.o.cursorcolumn = true -- 启用当前列高亮
vim.g.vimsyn_embed = "alpPrj" -- 嵌入语法高亮
-- vim.o.textwidth = 1000 -- 超过 1000 列才换行
vim.o.wrap = false -- 显示换行
vim.o.linebreak = true -- 在单词边界换行（视觉更自然）
vim.o.showbreak = "↪ " -- 换行提示符（可选）
vim.opt.listchars:append({ precedes = "<", extends = ">" }) -- 长行可视化提示
vim.o.sidescroll = 5 -- 如果行仍然超出窗口宽度，水平滚动 5 列
vim.o.smoothscroll = true -- 开启平滑滚动
vim.o.undofile = true -- 启用持久撤销
vim.o.confirm = true -- 未保存退出确认
vim.o.spelloptions = "camel" -- 开启驼峰拼写检查
-- 限制 Neovim 在重绘时发送的最大行数
vim.o.maxcombine = 8 -- 最大组合字符数

-- -------------- 折叠设置 --------------
-- 设置折叠表达式
-- ufo插件接管
-- vim.o.foldmethod = "expr"
-- vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- vim.o.foldlevelstart = 99 -- 默认展开所有内容
-- vim.o.foldcolumn = "1" -- 显示折叠列
vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"

-- -------------- 编辑行为设置 --------------
vim.o.expandtab = true -- 将 Tab 转为空格
vim.o.tabstop = 2 -- 设置 Tab 为 2 个空格宽度
vim.o.shiftwidth = 2 -- 设置自动缩进为 2 个空格
vim.o.scrolloff = 8 -- 保持光标上方和下方至少 8 行可见
vim.o.sidescrolloff = 5 -- 保持光标左右至少 5 列可见

-- shada设置
vim.o.exrc = true -- 启用 exrc 配置
vim.o.secure = true -- 启用安全模式
-- 生成唯一的 shada 文件路径
local workspace_path = vim.fn.getcwd()
local data_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8)
local shadafile = data_dir .. "/shada/" .. unique_id .. ".shada"
vim.o.shadafile = shadafile
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,globals,tabpages,winsize,winpos,terminal,localoptions,options"

-- -------------- 补全设置 --------------
vim.bo.omnifunc = "" -- 禁用 omnifunc 补全
vim.o.complete = "" -- 禁用补全
-- vim.o.completeopt = "menuone,noinsert,noselect" -- 补全菜单的选项
vim.o.completeopt = "menu,menuone,popup,fuzzy" -- 现代补全菜单
-- vim.o.autocomplete = true -- 启用自动补全

-- -------------- 搜索设置 --------------
vim.o.ignorecase = true -- 搜索时忽略大小写
vim.o.smartcase = true -- 智能区分大小写

-- -------------- 窗口和分割设置 --------------
vim.o.splitbelow = true -- 新分割窗口默认在下方
vim.o.splitright = true -- 新分割窗口默认在右边
vim.o.splitkeep = "screen" -- 保持分割窗口屏幕位置
vim.o.winborder = "rounded" -- 浮动窗口边框

-- -------------- 状态栏和标签页 --------------
vim.o.showmode = false -- 禁用模式显示
vim.o.laststatus = 3 -- 启用全局状态栏
vim.o.cmdheight = 0 -- 状态栏高度 PS:< 0 noice插件会在启动时产生跳动
vim.o.showtabline = 2 -- 始终显示标签页栏
vim.o.statuscolumn = "%s%=%l%=%C "
vim.o.number = true --显示行号
vim.o.relativenumber = true -- 启用相对行号
vim.o.signcolumn = "yes:3" -- 始终显示标志列
vim.o.tabclose = "left,uselast" -- 关闭当前标签页后，会自动切换到最近使用过的标签页（如果有）
-- vim.o.messagesopt = "wait:500,history:2000" -- 消息选项：等待 500 毫秒，历史记录 1000 行
-- 启用 UI2（Neovim 0.12 的渲染层）
require("vim._core.ui2").enable({
	enable = true,
	msg = {
		targets = {
			[""] = "cmd",
			empty = "cmd",
			bufwrite = "msg",
			confirm = "cmd",
			emsg = "msg",
			echo = "msg",
			echomsg = "msg",
			echoerr = "msg",
			completion = "cmd",
			list_cmd = "pager",
			lua_error = "msg",
			lua_print = "msg",
			progress = "msg",
			rpc_error = "msg",
			quickfix = "msg",
			search_cmd = "cmd",
			search_count = "cmd",
			shell_cmd = "pager",
			shell_err = "pager",
			shell_out = "pager",
			shell_ret = "msg",
			undo = "msg",
			verbose = "pager",
			wildlist = "cmd",
			wmsg = "msg",
			typed_cmd = "cmd",
		},
		cmd = {
			height = 0.5,
		},
		dialog = {
			height = 0.5,
		},
		msg = {
			height = 0.5,
			timeout = 4000,
		},
		pager = {
			height = 3,
		},
	},
})

-- -------------- 显示和符号设置 --------------
vim.o.list = true -- 显示不可见字符
-- vim.wo.foldtext = ""
vim.opt.fillchars = {
	stl = " ", -- 当前窗口的状态栏区域字符
	stlnc = " ", -- 非当前窗口的状态栏区域字符
	wbr = " ", -- winbar 区域字符
	-- 水平分隔符字符
	horiz = "", -- 水平分隔符（例如 :split 使用）
	horizup = "", -- 向上的水平分隔符
	horizdown = "", -- 向下的水平分隔符
	-- 垂直分隔符字符
	vert = "", -- 垂直分隔符（例如 :vsplit 使用）
	vertleft = "", -- 向左的垂直分隔符
	vertright = "", -- 向右的垂直分隔符
	verthoriz = "", -- 垂直和水平重叠的分隔符
	-- 折叠相关字符
	fold = " ", -- 折叠文本填充字符
	foldopen = "◌", -- 折叠打开时的标记字符
	foldclose = "◉", -- 折叠关闭时的标记字符
	foldsep = "│", -- 打开折叠时的中间分隔符
	foldinner = " ", -- 折叠层级，默认显示数字
	-- 其他
	diff = "╱", -- 显示差异时，已删除的行字符
	msgsep = " ", -- 消息分隔符字符（例如用于 `display`）
	eob = " ", -- 空行字符（用于表示缓冲区末尾）
	lastline = "@", -- 最后一行或截断字符
}

vim.opt.listchars = {
	tab = "╎ ", -- 显示 Tab 字符
	-- leadmultispace = "-", -- 显示多余空格
	multispace = " ",
	trail = "␣", -- 显示尾随空格
	nbsp = " ", -- 显示不间断空格
	eol = " ", -- 换行符
}
