local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

M.palette = {
	-- 基础颜色
	bg = "#1e1e2e", -- 背景色
	fg = "#cdd6f4", -- 前景色（文字颜色）

	-- 常用基础色
	red = "#f38ba8", -- 红色，用于错误
	green = "#a6e3a1", -- 绿色，用于成功、通过
	green3 = "#00CD00",
	blue = "#89b4fa", -- 蓝色，用于信息
	yellow = "#f9e2af", -- 黄色，用于警告
	magenta = "#f5c2e7", -- 洋红，用于强调
	cyan = "#94e2d5", -- 青色，用于提示
	gray = "#6c7086", -- 灰色
	darkgray = "#45475a", -- 深灰色

	-- 语义颜色（用于诊断等场景）
	error = "#f38ba8", -- 错误
	warning = "#f9e2af", -- 警告
	info = "#89dceb", -- 信息
	hint = "#74c7ec", -- 提示
}

M.close_commands = {
	help = "quit", -- 专属窗口
	man = "quit",
	msgmore = "quit",
	FunctionReferences = "quit",

	checkhealth = "close", -- 通常是浮窗
	-- qf = "close", -- quickfix 通常是浮窗
	better_term = "close", -- term 为 buffer
	["grug-far"] = "bdelete",
	git = "bdelete",

	terminal = "bdelete", -- term 窗口通常是 buffer
	-- nofile = "bdelete", -- `nofile` 可能是 dashboard 等 buffer

	["dap-repl"] = "close", -- 浮窗
	["dap-float"] = "close", -- 浮窗
	["dap-view-term"] = "close", -- 终端 view，浮窗

	["dap-view"] = function()
		vim.cmd("DapViewClose!")
	end,

	DiffviewFiles = function()
		vim.cmd("DiffviewClose")
	end,

	DiffviewFileHistory = function()
		vim.cmd("DiffviewClose")
	end,
}

return M
