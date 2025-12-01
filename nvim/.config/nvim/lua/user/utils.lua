local M = {}

M.settings = {
	["dap-repl"] = {
		setup = function()
			-- 仅在当前 buffer 中禁用保存确认提示
			vim.opt_local.confirm = false
		end,
	},
}

M.buf_keymaps = {
	-- 统一使用按键作为顶级键
	["q"] = {
		help = { cmd = "quit" },
		man = { cmd = "quit" },
		msgmore = { cmd = "quit" },
		FunctionReferences = { cmd = "quit" },
		checkhealth = { cmd = "close" },
		gitgraph = { cmd = "bdelete!" },
		better_term = { cmd = "close" },
		["grug-far"] = { cmd = "bdelete" },
		git = { cmd = "bdelete" },
		["dap-repl"] = { cmd = "close" },
		["dap-float"] = { cmd = "close" },
		["dap-view-term"] = { cmd = "close" },
		["gitsigns-blame"] = { cmd = "bdelete!" },
		terminal = { cmd = "bdelete" },
		["nvim-undotree"] = { cmd = "close" },
		["vscode-diff-explorer"] = { cmd = "tabclose" },
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

return M
