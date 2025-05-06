local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

M.close_commands = {
	help = "quit", -- 专属窗口
	man = "quit",

	checkhealth = "close", -- 通常是浮窗
	qf = "close", -- quickfix 通常是浮窗
	toggleterm = "bdelete", -- term 为 buffer
	["grug-far"] = "bdelete",
	git = "bdelete",

	terminal = "bdelete", -- term 窗口通常是 buffer
	nofile = "bdelete", -- `nofile` 可能是 dashboard 等 buffer

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
